# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :e2e do
  desc 'Run Playwright tests against all dev modes (bin/dev, bin/dev static, bin/dev prod)'
  task :test_all_modes do
    modes = [
      { name: 'Development (bin/dev)', command: 'bin/dev', env: {} },
      { name: 'Development Static (bin/dev static)', command: 'bin/dev static', env: {} },
      { name: 'Development Production (bin/dev prod)', command: 'bin/dev prod', env: {} }
    ]

    results = {}

    modes.each do |mode|
      puts "\n#{'=' * 80}"
      puts "Testing: #{mode[:name]}"
      puts '=' * 80

      server_pid = nil
      begin
        # Start the server in the background
        puts "Starting server: #{mode[:command]}..."
        server_pid = spawn(mode[:env], mode[:command], out: File::NULL, err: File::NULL)

        # Wait for server to be ready
        puts 'Waiting for server to be ready...'
        max_attempts = 60
        attempt = 0
        server_ready = false

        while attempt < max_attempts
          begin
            require 'net/http'
            response = Net::HTTP.get_response(URI('http://localhost:3000'))
            if response.code.to_i < 500
              server_ready = true
              break
            end
          rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, SocketError
            # Server not ready yet
          end
          sleep 1
          attempt += 1
          print '.'
        end

        puts ''

        unless server_ready
          puts "ERROR: Server failed to start for #{mode[:name]}"
          results[mode[:name]] = { success: false, error: 'Server failed to start' }
          next
        end

        puts 'Server is ready! Running Playwright tests...'

        # Run Playwright tests
        test_env = mode[:env].merge({ 'SKIP_WEB_SERVER' => 'true' })
        success = system(test_env, 'npx playwright test')

        results[mode[:name]] = { success: success }
      rescue StandardError => e
        puts "ERROR: #{e.message}"
        results[mode[:name]] = { success: false, error: e.message }
      ensure
        # Stop the server and all child processes
        if server_pid
          puts 'Stopping server...'
          begin
            # Kill the entire process group (negative PID)
            # This ensures bin/dev's child processes (Rails, webpack, etc.) are also terminated
            Process.kill('TERM', -server_pid)
            sleep 1
            # Force kill any remaining processes
            begin
              Process.kill('KILL', -server_pid)
            rescue StandardError
              nil
            end
            Process.wait(server_pid)
          rescue Errno::ESRCH, Errno::ECHILD
            # Process already terminated
          end
        end

        # Give the server time to shut down and release ports
        sleep 2
      end
    end

    # Print summary
    puts "\n#{'=' * 80}"
    puts 'TEST SUMMARY'
    puts '=' * 80

    results.each do |mode_name, result|
      status = result[:success] ? '✅ PASSED' : '❌ FAILED'
      puts "#{status} - #{mode_name}"
      puts "  Error: #{result[:error]}" if result[:error]
    end

    # Exit with error if any tests failed
    exit 1 unless results.values.all? { |r| r[:success] }
  end

  desc 'Run Playwright tests (assumes server is already running)'
  task test: :environment do
    exec 'bin/rails playwright:run'
  end

  desc 'Open Playwright test UI'
  task open: :environment do
    exec 'bin/rails playwright:open'
  end

  desc 'Show Playwright test report'
  task report: :environment do
    exec 'npx playwright show-report'
  end
end
# rubocop:enable Metrics/BlockLength
