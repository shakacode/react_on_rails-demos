# frozen_string_literal: true

require 'open3'

module DemoScripts
  # Shared module for command execution with dry-run support
  #
  # Output behavior:
  # - In verbose mode: All command output goes to stdout
  # - On command failure (non-verbose): Error output goes to stderr for debugging
  # - On command success (non-verbose): No output is shown
  module CommandExecutor
    # rubocop:disable Naming/PredicateMethod
    # run_command is intentionally not a predicate method despite allow_failure parameter
    def run_command(command, allow_failure: false)
      if @dry_run
        puts "  [DRY-RUN] #{command}"
        return true
      end

      begin
        output, status = Open3.capture2e(command)
      rescue SystemCallError => e
        raise Error, "Failed to execute command '#{command}': #{e.message}"
      end

      # Show output in verbose mode (stdout)
      puts output if @verbose

      # Show output on failure (stderr) for debugging, unless in verbose mode (already shown)
      warn output if !status.success? && !@verbose

      raise Error, "Command failed: #{command}" unless status.success? || allow_failure

      status.success?
    end
    # rubocop:enable Naming/PredicateMethod

    def command_exists?(command)
      system('which', command, out: File::NULL, err: File::NULL)
    end

    def capture_command(command)
      return '' if @dry_run

      begin
        output, status = Open3.capture2e(command)
        raise Error, "Command failed: #{command}" unless status.success?

        output.strip
      rescue SystemCallError => e
        raise Error, "Failed to execute command '#{command}': #{e.message}"
      end
    end
  end
end
