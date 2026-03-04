# frozen_string_literal: true

class TanstackAppController < ApplicationController
  layout "tanstack_app"

  def index
    # Pass the current URL path to React for proper SSR routing
    @tanstack_props = {
      initialUrl: request.fullpath
    }
  end
end
