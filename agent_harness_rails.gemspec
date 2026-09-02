# frozen_string_literal: true

require_relative "lib/agent_harness_rails/version"

Gem::Specification.new do |spec|
  # Underscored so the gem name, the require, and the AgentHarnessRails constant
  # all match. The harness it vendors keeps its own name: agent_harness_rails/.
  spec.name = "agent_harness_rails"
  spec.version = AgentHarnessRails::VERSION
  spec.authors = [ "Chris Bellairs" ]
  spec.email = [ "chris@pitchd.ai" ]

  spec.summary = "Rails conventions for coding agents — skills, rules, and agent definitions."
  spec.description = <<~TEXT.gsub("\n", " ").strip
    Vendors a harness of skills, rules, and agent definitions into a Rails
    application so Cursor and Claude Code can read them from the project
    directory alone. Conventions follow opinionated Rails best practice: omakase
    defaults, server-owned truth, REST-shaped boundaries, Hotwire-first front ends, and a
    plan / implement / review loop.
  TEXT

  spec.homepage = "https://github.com/chrisrackstallion/agent_harness_rails"
  spec.license = "MIT"
  # The oldest Ruby still receiving upstream support. The floor tracks Ruby's
  # EOL schedule, not Rails: every Rails version this harness accommodates
  # (7.2 up) runs on Ruby 3.3, so raising it strands no Rails app — and
  # Rails/StrongParametersExpect in rubocop-harness.yml still gates itself on
  # the railties version, so a Rails 7 app sees no params.expect offences.
  #
  # .rubocop.yml pins TargetRubyVersion to match, and spec/gem_spec.rb asserts the
  # two agree — so a cop can never suggest syntax a consuming app cannot run.
  spec.required_ruby_version = ">= 3.3"

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
    payload = Dir.glob("agent_harness_rails/**/*", File::FNM_DOTMATCH)
                 .select { |path| File.file?(path) }
                 .reject { |path| File.basename(path).start_with?(".") }

    # Every rubocop config is shipped so apps can `inherit_gem` them — see the
    # README. rubocop.yml is the thin omakase layer; the rubocop-harness-*.yml
    # files are the opt-in enforcement layers.
    # config/default.yml carries the custom cops' defaults. RuboCop loads it by
    # path at require time, so leaving it out breaks cop loading in a consuming
    # app and nowhere else — spec/gem_spec.rb asserts it is here.
    payload +
      Dir.glob("lib/**/*.rb") +
      Dir.glob("config/*.yml") +
      [ "exe/agent_harness_rails", "LICENSE", "README.md", "CHANGELOG.md",
        "rubocop.yml", "rubocop-harness.yml", "rubocop-harness-rspec.yml", "rubocop-harness-index.yml" ]
        .select { |f| File.exist?(f) }
  end

  spec.bindir = "exe"
  # One executable, named for the gem. `install`, `update`, and `check` manage
  # the vendored harness; `evals` checks that every intent clause in
  # docs/primitives/ is proven by a spec, in CI beside RuboCop.
  spec.executables = [ "agent_harness_rails" ]
  spec.require_paths = [ "lib" ]
end
