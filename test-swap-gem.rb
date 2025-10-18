#!/usr/bin/env ruby
# frozen_string_literal: true

require 'swap_shakacode_deps'

# Test the gem functionality
include SwapShakacodeDeps::GitHubSpecParser

puts "Testing GitHubSpecParser:"
specs = [
  "shakacode/shakapacker",
  "shakacode/react_on_rails#main",
  "shakacode/cypress-on-rails@v1.0.0"
]

specs.each do |spec|
  repo, ref, ref_type = parse_github_spec(spec)
  puts "  #{spec} -> repo: #{repo}, ref: #{ref || 'nil'}, type: #{ref_type || 'nil'}"
end

puts "\nTesting BackupManager:"
backup = SwapShakacodeDeps::BackupManager.new(dry_run: true, verbose: true)
puts "  backup_exists? for Gemfile: #{backup.backup_exists?('Gemfile')}"

puts "\nGem is working! The modules are implemented."
puts "Note: The CLI needs the Swapper orchestrator to be completed."