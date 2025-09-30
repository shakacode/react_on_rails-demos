# frozen_string_literal: true

module DemoScripts
  # Runs commands with dry-run support
  class CommandRunner
    attr_reader :dry_run

    def initialize(dry_run: false, verbose: true)
      @dry_run = dry_run
      @verbose = verbose
    end

    def run(command, dir: nil)
      full_command = dir ? "cd '#{dir}' && #{command}" : command

      if @dry_run
        puts "[DRY-RUN] #{full_command}"
        return true
      end

      puts "▶ #{full_command}" if @verbose

      system(full_command)
    end

    def run!(command, dir: nil)
      success = run(command, dir: dir)
      return if success || @dry_run

      raise CommandError, "Command failed: #{command}"
    end

    def capture(command, dir: nil)
      full_command = dir ? "cd '#{dir}' && #{command}" : command

      if @dry_run
        puts "[DRY-RUN] #{full_command}"
        return ""
      end

      `#{full_command}`.strip
    end
  end
end