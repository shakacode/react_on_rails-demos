# frozen_string_literal: true

require 'rails/railtie'

module ShakacodeDemoCommon
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/shakacode_demo_common.rake'
    end

    generators do
      require 'generators/shakacode_demo_common/install/install_generator'
    end
  end
end
