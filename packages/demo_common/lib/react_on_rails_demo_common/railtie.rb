# frozen_string_literal: true

require 'rails/railtie'

module ReactOnRailsDemoCommon
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/demo_common.rake'
    end

    generators do
      require 'generators/react_on_rails_demo_common/install/install_generator'
    end
  end
end
