# frozen_string_literal: true

require_relative 'lib/swap_shakacode_deps/version'

Gem::Specification.new do |spec|
  spec.name = 'swap-shakacode-deps'
  spec.version = SwapShakacodeDeps::VERSION
  spec.authors = ['ShakaCode']
  spec.email = ['contact@shakacode.com']

  spec.summary = 'Swap Shakacode gem dependencies between local and production versions'
  spec.description = <<~DESC
    A command-line tool for swapping Shakacode gem dependencies (shakapacker, react_on_rails,
    cypress-on-rails) between production versions and local development paths or GitHub branches.
    Supports automatic backup/restore, npm package building, and watch mode for development.
  DESC
  spec.homepage = 'https://github.com/shakacode/swap-shakacode-deps'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/shakacode/swap-shakacode-deps'
  spec.metadata['changelog_uri'] = 'https://github.com/shakacode/swap-shakacode-deps/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released
  spec.files = Dir.glob('{bin,lib}/**/*', File::FNM_DOTMATCH) +
               %w[README.md LICENSE CHANGELOG.md]
  spec.bindir = 'bin'
  spec.executables = ['swap-shakacode-deps']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'json', '~> 2.0'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.22'

  spec.metadata['rubygems_mfa_required'] = 'true'
end