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

      if dir
        # Use Bundler.with_unbundled_env to ensure bundle commands in subdirectories
        # use their own Gemfile instead of inheriting the parent's bundle environment
        Bundler.with_unbundled_env do
          Dir.chdir(dir) { system(command) }
        end
      else
        system(command)
      end
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
        return ''
      end

      if dir
        # Use Bundler.with_unbundled_env to ensure bundle commands in subdirectories
        # use their own Gemfile instead of inheriting the parent's bundle environment
        Bundler.with_unbundled_env do
          Dir.chdir(dir) { `#{command}`.strip }
        end
      else
        `#{command}`.strip
      end
    end
  end
end
