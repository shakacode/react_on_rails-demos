# frozen_string_literal: true

require_relative 'lib/shakacode_demo_common/version'

Gem::Specification.new do |spec|
  spec.name        = 'shakacode_demo_common'
  spec.version     = ShakacodeDemoCommon::VERSION
  spec.authors     = ['Justin Gordon']
  spec.email       = ['justin@shakacode.com']
  spec.summary     = 'Common configuration for React on Rails demo applications'
  spec.description = 'Shared linting, testing, deployment, and development configurations for React on Rails demos'
  spec.homepage    = 'https://github.com/shakacode/react_on_rails-demos'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'cypress-on-rails', '~> 1.0'
  spec.add_dependency 'rails', '>= 7.0'
  spec.add_dependency 'rubocop', '~> 1.50'
  spec.add_dependency 'rubocop-performance', '~> 1.17'
  spec.add_dependency 'rubocop-rails', '~> 2.19'

  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
