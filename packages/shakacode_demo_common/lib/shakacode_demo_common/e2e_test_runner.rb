# frozen_string_literal: true

require 'net/http'
require 'uri'

module ShakacodeDemoCommon
  # Manages end-to-end test execution across different server modes
  class E2eTestRunner
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
      sleep 2 # Give server time to shut down and release ports
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
    DEFAULT_URL = 'http://localhost:3000'
    MAX_STARTUP_ATTEMPTS = 60
    STARTUP_CHECK_INTERVAL = 1 # second

    attr_reader :mode

    def initialize(mode)
      @mode = mode
      @server_pid = nil
      @ready = false
    end

    def start
      puts "Starting server: #{@mode[:command]}..."
      @server_pid = spawn(@mode[:env], @mode[:command], out: File::NULL, err: File::NULL)
    end

    # rubocop:disable Naming/PredicateMethod
    def wait_until_ready
      puts 'Waiting for server to be ready...'

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
      response = Net::HTTP.get_response(URI(DEFAULT_URL))
      response.code.to_i < 500
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, SocketError
      false
    end

    def terminate_server_process
      # Kill the entire process group (negative PID)
      # This ensures bin/dev's child processes (Rails, webpack, etc.) are also terminated
      Process.kill('TERM', -@server_pid)
      sleep 1

      # Force kill any remaining processes
      begin
        Process.kill('KILL', -@server_pid)
      rescue StandardError
        nil
      end

      Process.wait(@server_pid)
    rescue Errno::ESRCH, Errno::ECHILD
      # Process already terminated
      nil
    end
  end
end
