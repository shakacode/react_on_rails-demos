# frozen_string_literal: true

require_relative 'swap_shakacode_deps/version'
require_relative 'swap_shakacode_deps/error'
require_relative 'swap_shakacode_deps/github_spec_parser'
require_relative 'swap_shakacode_deps/backup_manager'
require_relative 'swap_shakacode_deps/cache_manager'
require_relative 'swap_shakacode_deps/watch_manager'
require_relative 'swap_shakacode_deps/gem_swapper'
require_relative 'swap_shakacode_deps/npm_swapper'
require_relative 'swap_shakacode_deps/config_loader'
require_relative 'swap_shakacode_deps/swapper'
require_relative 'swap_shakacode_deps/cli'

# Main module for swap-shakacode-deps gem
module SwapShakacodeDeps
  # Supported Shakacode gems
  SUPPORTED_GEMS = %w[shakapacker react_on_rails cypress-on-rails].freeze

  # NPM package paths within each gem
  NPM_PACKAGE_PATHS = {
    'shakapacker' => '.',
    'react_on_rails' => 'node_package',
    'cypress-on-rails' => nil # Ruby-only gem
  }.freeze
end
