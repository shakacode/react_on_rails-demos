# frozen_string_literal: true

require 'demo_common/version'
require 'demo_common/railtie' if defined?(Rails)

module DemoCommon
  class Error < StandardError; end

  class << self
    def root
      Pathname.new(File.expand_path('..', __dir__))
    end

    def config_path
      root.join('config')
    end

    def templates_path
      root.join('lib', 'generators', 'templates')
    end
  end
end
