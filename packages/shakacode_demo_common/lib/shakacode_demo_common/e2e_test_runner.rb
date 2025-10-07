# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'socket'

module ShakacodeDemoCommon
  # Manages end-to-end test execution across different server modes
  class E2eTestRunner
    MAX_PORT_CLEANUP_ATTEMPTS = 10
    PORT_CLEANUP_CHECK_INTERVAL = 0.5 # seconds
    PORT_CONNECTION_TIMEOUT = 0.1 # seconds - fast check for port availability

    attr_reader :results

    def initialize(modes)
      @modes = modes
      @results = {}
    end

    def run_all
      @modes.each_with_index do |mode, index|
        print_test_header(mode[:name])
        @results[mode[:name]] = run_mode(mode)

        # Only cleanup between modes, not after the last one
        next if index == @modes.length - 1

        puts 'WARNING: Proceeding despite port cleanup timeout - next test may fail' unless cleanup_between_modes
      end

      print_summary
      exit_with_status
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

    # rubocop:disable Naming/PredicateMethod
    def cleanup_between_modes
      puts 'Waiting for server to release port...'
      MAX_PORT_CLEANUP_ATTEMPTS.times do
        return true unless port_in_use?(ServerManager::DEFAULT_PORT)

        sleep PORT_CLEANUP_CHECK_INTERVAL
      end
      puts "Warning: Port #{ServerManager::DEFAULT_PORT} may still be in use"
      false
    end
    # rubocop:enable Naming/PredicateMethod

    # Check if a port is in use by attempting to connect to it
    # Returns true if something is listening on the port, false if port is free
    # Uses Socket.tcp for a lighter check than creating a TCPServer
    def port_in_use?(port)
      Socket.tcp('localhost', port, connect_timeout: PORT_CONNECTION_TIMEOUT).close
      true # If connection succeeds, something is listening
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
      false # Port is free
    rescue Errno::EADDRINUSE
      true # Port is in use
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
  end

  # Manages server lifecycle for e2e testing
  class ServerManager
    DEFAULT_PORT = 3000
    MAX_STARTUP_ATTEMPTS = 60
    STARTUP_CHECK_INTERVAL = 1 # second
    INITIAL_STARTUP_DELAY = 2 # seconds - give server time to initialize before checking
    HTTP_OPEN_TIMEOUT = 2 # seconds - timeout for opening HTTP connection
    HTTP_READ_TIMEOUT = 5 # seconds - timeout for reading HTTP response (longer for slow CI/asset compilation)

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
      url = URI("http://localhost:#{@port}")
      response = Net::HTTP.start(url.host, url.port,
                                 open_timeout: HTTP_OPEN_TIMEOUT,
                                 read_timeout: HTTP_READ_TIMEOUT) do |http|
        http.get(url.path.empty? ? '/' : url.path)
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
