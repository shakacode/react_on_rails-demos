# frozen_string_literal: true

require 'net/http'
require 'uri'

module ShakacodeDemoCommon
  # Manages end-to-end test execution across different server modes
  class E2eTestRunner
    # Port availability polling configuration
    DEFAULT_PORT = 3000
    PORT_CHECK_MAX_ATTEMPTS = 10
    PORT_CHECK_INTERVAL = 0.5 # seconds

    attr_reader :results

    def initialize(modes)
      @modes = modes
      @results = {}
    end

    def run_all
      @modes.each do |mode|
        print_test_header(mode[:name])
        @results[mode[:name]] = run_mode(mode)
        cleanup_between_modes
      end

      print_summary
      exit_with_status
    end

    def print_test_header(mode_name)
      puts "\n#{'=' * 80}"
      puts "Testing: #{mode_name}"
      puts '=' * 80
    end

    def print_summary
      puts "\n#{'=' * 80}"
      puts 'TEST SUMMARY'
      puts '=' * 80

      @results.each do |mode_name, result|
        status = result[:success] ? '✅ PASSED' : '❌ FAILED'
        puts "#{status} - #{mode_name}"
        puts "  Error: #{result[:error]}" if result[:error]
      end
    end

    def exit_with_status
      exit 1 unless @results.values.all? { |r| r[:success] }
    end

    private

    def run_mode(mode)
      server = ServerManager.new(mode)

      begin
        server.start
        server.wait_until_ready

        return { success: false, error: 'Server failed to start' } unless server.ready?

        success = run_playwright_tests(mode[:env])
        { success: success }
      rescue StandardError => e
        { success: false, error: e.message }
      ensure
        server.stop
      end
    end

    def run_playwright_tests(env)
      test_env = env.merge({ 'SKIP_WEB_SERVER' => 'true' })
      puts 'Server is ready! Running Playwright tests...'
      system(test_env, 'npx playwright test')
    end

    def cleanup_between_modes
      puts 'Waiting for server to release port...'
      return if port_available?

      # Port is still in use after timeout - fail fast in CI to prevent flaky tests
      raise 'Port still in use after timeout. Failing to prevent flaky tests in CI.' if ENV['CI']

      puts 'Warning: Continuing despite port possibly being in use'
    end

    # Checks if port becomes available within timeout period
    # Returns true if port becomes available, false if timeout reached
    def port_available?(port = DEFAULT_PORT, max_attempts = PORT_CHECK_MAX_ATTEMPTS,
                        check_interval = PORT_CHECK_INTERVAL)
      max_attempts.times do
        return true unless port_in_use?(port)

        print '.'
        sleep check_interval
      end
      puts ''
      puts "Warning: Port #{port} may still be in use after #{max_attempts * check_interval} seconds"
      false
    end

    def port_in_use?(port)
      require 'socket'
      server = nil
      begin
        server = TCPServer.new('127.0.0.1', port)
        false # Port is available
      rescue Errno::EADDRINUSE
        true # Port is in use
      rescue StandardError => e
        # On unexpected errors (permissions, etc.), assume port is in use to be safe
        puts "Warning: Error checking port availability: #{e.message}"
        puts 'Assuming port is in use to be safe'
        true
      ensure
        server&.close
      end
    end
  end

  # Manages server lifecycle for e2e testing
  class ServerManager
    DEFAULT_PORT = 3000
    MAX_STARTUP_ATTEMPTS = 60
    STARTUP_CHECK_INTERVAL = 1 # second
    INITIAL_STARTUP_DELAY = 2 # seconds - give server time to initialize before checking
    HTTP_OPEN_TIMEOUT = 2 # seconds
    HTTP_READ_TIMEOUT = 2 # seconds

    attr_reader :mode

    def initialize(mode, port: DEFAULT_PORT)
      @mode = mode
      @port = port
      @server_pid = nil
      @server_pgid = nil
      @ready = false
    end

    def start
      puts "Starting server: #{@mode[:command]}..."
      # Start server in its own process group so we can kill the entire group
      @server_pid = spawn(@mode[:env], @mode[:command], out: File::NULL, err: File::NULL, pgroup: true)
      # Get the process group ID for later termination
      @server_pgid = Process.getpgid(@server_pid)
    rescue StandardError => e
      # If we can't get pgid, we'll fall back to killing just the PID
      puts "Warning: Failed to get process group ID: #{e.message}"
      @server_pgid = nil
    end

    # rubocop:disable Naming/PredicateMethod
    def wait_until_ready
      puts 'Waiting for server to be ready...'

      # Give server time to initialize before checking
      sleep INITIAL_STARTUP_DELAY

      MAX_STARTUP_ATTEMPTS.times do
        if server_responding?
          @ready = true
          puts ''
          return true
        end

        print '.'
        sleep STARTUP_CHECK_INTERVAL
      end

      puts ''
      false
    end
    # rubocop:enable Naming/PredicateMethod

    def ready?
      @ready
    end

    def stop
      return unless @server_pid

      puts 'Stopping server...'
      terminate_server_process
    end

    private

    def server_responding?
      url = "http://localhost:#{@port}"
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port,
                                 open_timeout: HTTP_OPEN_TIMEOUT,
                                 read_timeout: HTTP_READ_TIMEOUT) do |http|
        http.get(uri.path.empty? ? '/' : uri.path)
      end
      # Accept 200-399 (success and redirects), reject 404 and 5xx
      (200..399).cover?(response.code.to_i)
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, SocketError, Net::OpenTimeout, Net::ReadTimeout
      false
    end

    def terminate_server_process
      send_term_signal
      sleep 1
      send_kill_signal
      Process.wait(@server_pid)
    rescue Errno::ESRCH, Errno::ECHILD
      # Process already terminated
      nil
    end

    def send_term_signal
      # Kill the entire process group if we have a valid pgid
      # This ensures bin/dev's child processes (Rails, webpack, etc.) are also terminated
      if @server_pgid
        Process.kill('TERM', -@server_pgid)
      else
        # Fall back to killing just the main process
        safe_kill_process('TERM', @server_pid)
      end
    rescue Errno::ESRCH, Errno::EPERM => e
      # Process group doesn't exist or permission denied, try single process
      puts "Warning: Failed to kill process group #{@server_pgid}: #{e.message}, trying single process"
      safe_kill_process('TERM', @server_pid)
    end

    def send_kill_signal
      # Force kill any remaining processes
      if @server_pgid
        Process.kill('KILL', -@server_pgid)
      else
        safe_kill_process('KILL', @server_pid)
      end
    rescue Errno::ESRCH, Errno::EPERM => e
      puts "Warning: Failed to kill process group #{@server_pgid}: #{e.message}, trying single process"
      safe_kill_process('KILL', @server_pid)
    end

    def safe_kill_process(signal, pid)
      Process.kill(signal, pid)
    rescue StandardError
      nil
    end
  end
end
