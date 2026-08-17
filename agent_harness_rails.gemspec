# frozen_string_literal: true

require_relative "lib/agent_harness_rails/version"

Gem::Specification.new do |spec|
  # Underscored so the gem name, the require, and the AgentHarnessRails constant
  # all match. The harness it vendors keeps its own name: rails-agent-harness/.
  spec.name = "agent_harness_rails"
  spec.version = AgentHarnessRails::VERSION
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

  spec.homepage = "https://github.com/chrisrackstallion/agent_harness_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Explicit include list rather than exclusion: the payload is the point, and
  # nothing in .claude/, .cursor/, docs/, or the dev bin/ belongs in the gem.
  # The .claude and .cursor entries are symlinks for developing this repo — they
  # are recreated per-app by `install`, never shipped.
  # Literal rather than AgentHarnessRails::PAYLOAD_DIR: a gemspec should not load
  # the library it packages. The two must agree — spec/gem_spec.rb asserts it.
  # Dir.chdir keeps the globs anchored to this file, so `gem build` works from
  # any working directory.
  spec.files = Dir.chdir(__dir__) do
    payload = Dir.glob("rails-agent-harness/**/*", File::FNM_DOTMATCH)
                 .select { |path| File.file?(path) }
                 .reject { |path| File.basename(path).start_with?(".") }

    # rubocop.yml is shipped so apps can `inherit_gem` it — see the README.
    payload +
      Dir.glob("lib/**/*.rb") +
      [ "exe/agent_harness_rails", "LICENSE", "README.md", "CHANGELOG.md", "rubocop.yml" ]
        .select { |f| File.exist?(f) }
  end

  spec.bindir = "exe"
  spec.executables = [ "agent_harness_rails" ]
  spec.require_paths = [ "lib" ]
end
