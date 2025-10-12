# frozen_string_literal: true

module SwapShakacodeDeps
  class Error < StandardError; end
  class ValidationError < Error; end
  class ConfigError < Error; end
  class BackupError < Error; end
  class CacheError < Error; end
end
