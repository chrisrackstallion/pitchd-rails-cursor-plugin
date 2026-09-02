# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", require: false
gem "rspec", "~> 3.13"
gem "rubocop", "~> 1.66", require: false
gem "rubocop-rails-omakase", require: false

# Not used to lint this repo, which has no Rails specs. They are here so
# spec/rubocop_config_spec.rb can assert that every cop rubocop-harness-rspec.yml
# names actually resolves — the file ships a config for gems a consuming app
# supplies, and a renamed cop upstream would otherwise surface in that app's CI
# rather than this one's.
gem "rubocop-capybara", "~> 3.0", require: false
gem "rubocop-factory_bot", "~> 2.28", require: false
gem "rubocop-rspec", "~> 3.10", require: false
gem "rubocop-rspec_rails", "~> 2.32", require: false

# The optional project index behind rubocop-harness-index.yml. RuboCop loads it
# only when AllCops/UseProjectIndex is on, and a consuming app adds it to its own
# Gemfile; here it lets the cross-file cops run against fixtures.
gem "rubydex", require: false
