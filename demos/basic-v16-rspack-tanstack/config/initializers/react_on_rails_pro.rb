# frozen_string_literal: true

# React on Rails Pro Configuration (REQUIRED for this demo)
#
# This demo requires React on Rails Pro with the Node Renderer for SSR.
# TanStack Router uses Node.js APIs (setTimeout, clearTimeout, etc.) that
# are not available in the default ExecJS environment.
#
# Setup instructions: See docs/react-on-rails-pro-setup.md
# Free license: Contact team@shakacode.com or justin@shakacode.com
#
# See: https://github.com/shakacode/react_on_rails_pro

unless defined?(ReactOnRailsPro)
  raise <<~ERROR
    React on Rails Pro is required for this demo.

    TanStack Router requires Node.js APIs (setTimeout, clearTimeout, etc.)
    that are not available in the default ExecJS environment.

    Setup instructions:
    1. Get a free license: Contact team@shakacode.com or justin@shakacode.com
    2. Follow the setup guide: docs/react-on-rails-pro-setup.md

    For more information: https://www.shakacode.com/react-on-rails-pro/
  ERROR
end

ReactOnRailsPro.configure do |config|
  # Use Node Renderer for full Node.js environment support
  config.server_renderer = "NodeRenderer"

  # Node Renderer connection settings
  config.renderer_url = ENV.fetch("RENDERER_URL", "http://localhost:3800")
  config.renderer_password = ENV.fetch("RENDERER_PASSWORD", "tanstack-demo-renderer")

  # Timeout for SSR requests (in seconds)
  config.ssr_timeout = 10

  # Enable tracing for debugging (disable in production for performance)
  config.tracing = Rails.env.development?

  # How many times to retry on timeout
  config.renderer_request_retry_limit = Rails.env.production? ? 3 : 1

  # Never fall back to ExecJS - it doesn't support the APIs TanStack Router needs
  config.renderer_use_fallback_exec_js = false
end
