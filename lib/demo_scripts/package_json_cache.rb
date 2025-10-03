# frozen_string_literal: true

require 'json'

module DemoScripts
  # Cache for package.json reads to avoid multiple file operations
  module PackageJsonCache
    def read_package_json(dir = Dir.pwd)
      @package_json_cache ||= {}
      @package_json_cache[dir] ||= begin
        path = File.join(dir, 'package.json')
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      rescue JSON::ParserError => e
        warn "Warning: Failed to parse package.json in #{dir}: #{e.message}"
        {}
      end
    end

    def npm_script?(script_name, dir = Dir.pwd)
      package_json = read_package_json(dir)
      scripts = package_json['scripts'] || {}
      scripts.key?(script_name.to_s)
    end

    # Alias for backward compatibility
    alias has_npm_script? npm_script?

    def clear_package_json_cache
      @package_json_cache = {}
    end
  end
end
