# frozen_string_literal: true

Rails.application.routes.draw do
  # Root routes to TanStack app
  root "tanstack_app#index"

  # Direct routes for SSR support
  get "about", to: "tanstack_app#index"
  get "search", to: "tanstack_app#index"
  get "users", to: "tanstack_app#index"
  get "users/:userId", to: "tanstack_app#index"
  get "demo/nested", to: "tanstack_app#index"
  get "demo/nested/deep", to: "tanstack_app#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
