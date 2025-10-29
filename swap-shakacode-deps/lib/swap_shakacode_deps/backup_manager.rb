# frozen_string_literal: true

require 'fileutils'
require 'json'

module SwapShakacodeDeps
  # Manages backup and restore operations for Gemfiles and package.json files
  class BackupManager
    BACKUP_SUFFIX = '.backup'

    def initialize(**options)
      @dry_run = options[:dry_run]
      @verbose = options[:verbose]
    end

    # Creates a backup of the specified file
    def backup_file(file_path)
      backup_path = file_path + BACKUP_SUFFIX

      # If backup exists, check if the current file is already swapped
      if File.exist?(backup_path)
        if already_swapped?(file_path)
          puts '  ℹ️  Using existing backup (preserving original dependencies)' if @verbose
          return true
        else
          # File is not swapped but backup exists - inconsistent state
          raise BackupError, "Backup exists but file appears unswapped. Run --restore first or manually remove: #{File.basename(backup_path)}"
        end
      end

      if @dry_run
        puts "  [DRY-RUN] Would backup #{File.basename(file_path)}"
      else
        FileUtils.cp(file_path, backup_path)
        puts "  ✓ Created backup: #{File.basename(backup_path)}" if @verbose
      end
      true
    end

    # Restores a file from its backup
    def restore_file(file_path)
      backup_path = file_path + BACKUP_SUFFIX

      unless File.exist?(backup_path)
        return false # No backup to restore
      end

      if @dry_run
        puts "  [DRY-RUN] Would restore #{File.basename(file_path)}"
      else
        FileUtils.cp(backup_path, file_path)
        FileUtils.rm(backup_path)
        puts "  ✓ Restored #{File.basename(file_path)}"
      end
      true
    end

    # Checks if a backup exists for the specified file
    def backup_exists?(file_path)
      File.exist?(file_path + BACKUP_SUFFIX)
    end

    # Lists all backup files in a directory
    def list_backups(directory)
      Dir.glob(File.join(directory, "*#{BACKUP_SUFFIX}"))
    end

    private

    def already_swapped?(file_path)
      content = File.read(file_path)
      is_gemfile = file_path.end_with?('Gemfile')

      if is_gemfile
        # Check for path: or github: in Gemfile for supported gems
        content.match?(/^\s*gem\s+["'](?:shakapacker|react_on_rails|cypress-on-rails)["'],.*(?:path:|github:)/)
      else
        # Check for file: protocol in package.json
        begin
          data = JSON.parse(content)
          %w[dependencies devDependencies].any? do |type|
            deps = data[type]
            next false unless deps.is_a?(Hash)

            # Check if any Shakacode packages use file: protocol
            %w[shakapacker react-on-rails].any? do |pkg|
              deps[pkg].is_a?(String) && deps[pkg].start_with?('file:')
            end
          end
        rescue JSON::ParserError
          false
        end
      end
    end
  end
end
