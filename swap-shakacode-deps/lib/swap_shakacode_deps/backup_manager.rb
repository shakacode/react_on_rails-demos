# frozen_string_literal: true

module SwapShakacodeDeps
  # Manages backup and restore operations for Gemfiles and package.json files
  class BackupManager
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb backup methods

    BACKUP_SUFFIX = '.backup'

    def initialize(dry_run: false, verbose: false)
      @dry_run = dry_run
      @verbose = verbose
    end

    # Creates a backup of the specified file
    def backup_file(file_path)
      raise NotImplementedError, 'File backup will be implemented in the next iteration'
    end

    # Restores a file from its backup
    def restore_file(file_path)
      raise NotImplementedError, 'File restore will be implemented in the next iteration'
    end

    # Checks if a backup exists for the specified file
    def backup_exists?(file_path)
      File.exist?(file_path + BACKUP_SUFFIX)
    end

    # Lists all backup files in a directory
    def list_backups(directory)
      Dir.glob(File.join(directory, "*#{BACKUP_SUFFIX}"))
    end
  end
end
