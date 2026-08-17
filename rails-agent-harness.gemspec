# frozen_string_literal: true

require_relative "lib/rails_agent_harness/version"

Gem::Specification.new do |spec|
  spec.name = "rails-agent-harness"
  spec.version = RailsAgentHarness::VERSION
  spec.authors = [ "Chris Bellairs" ]
  spec.email = [ "chris@pitchd.ai" ]

  spec.summary = "Rails conventions for coding agents — skills, rules, and agent definitions."
  spec.description = <<~TEXT.gsub("\n", " ").strip
    Vendors a harness of skills, rules, and agent definitions into a Rails
    application so Cursor and Claude Code can read them from the project
    directory alone. Conventions follow DHH and 37signals: omakase defaults,
    server-owned truth, REST-shaped boundaries, Hotwire-first front ends, and a
    plan / implement / review loop.
  TEXT

  spec.homepage = "https://github.com/chrisrackstallion/rails-agent-harness"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Explicit include list rather than exclusion: the payload is the point, and
  # nothing in .claude/, .cursor/, docs/, or the dev bin/ belongs in the gem.
  # The .claude and .cursor entries are symlinks for developing this repo — they
  # are recreated per-app by `install`, never shipped.
  # Literal rather than RailsAgentHarness::PAYLOAD_DIR: a gemspec should not load
  # the library it packages. The two must agree — spec/gem_spec.rb asserts it.
  payload = Dir.glob("rails-agent-harness/**/*", File::FNM_DOTMATCH)
               .select { |path| File.file?(path) }
               .reject { |path| File.basename(path).start_with?(".") }

  spec.files = payload +
               Dir.glob("lib/**/*.rb") +
               [ "exe/rails-agent-harness", "LICENSE", "README.md" ].select { |f| File.exist?(f) }

  spec.bindir = "exe"
  spec.executables = [ "rails-agent-harness" ]
  spec.require_paths = [ "lib" ]
end
