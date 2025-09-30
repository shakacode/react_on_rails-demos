# frozen_string_literal: true

require_relative "demo_scripts/version"
require_relative "demo_scripts/config"
require_relative "demo_scripts/pre_flight_checks"
require_relative "demo_scripts/command_runner"
require_relative "demo_scripts/demo_creator"
require_relative "demo_scripts/demo_scaffolder"
require_relative "demo_scripts/demo_updater"

# Main module for demo scripts
module DemoScripts
  class Error < StandardError; end
  class PreFlightCheckError < Error; end
  class CommandError < Error; end
end