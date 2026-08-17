# frozen_string_literal: true

require "spec_helper"
require "yaml"

# Guards the packaging contract. The payload is the whole point of this gem, so
# the things most worth asserting are that it is actually included and that the
# constants and the gemspec agree.
RSpec.describe "gem packaging" do
  let(:spec) { Gem::Specification.load(File.expand_path("../rails-agent-harness.gemspec", __dir__)) }

  it "names the payload directory identically to the constant" do
    # The gemspec hardcodes the directory rather than loading the library.
    source = File.read(File.expand_path("../rails-agent-harness.gemspec", __dir__))

    expect(source).to include(%("#{RailsAgentHarness::PAYLOAD_DIR}/**/*"))
  end

  it "ships the payload, including nested references/" do
    expect(spec.files).to include("rails-agent-harness/rules/models.mdc")
    expect(spec.files).to include("rails-agent-harness/skills/writing-tests/references/system-specs.md")
    expect(spec.files).to include("rails-agent-harness/agents/rails-reviewer.md")
  end

  it "ships the library and executable" do
    expect(spec.files).to include("lib/rails_agent_harness.rb", "exe/rails-agent-harness")
    expect(spec.executables).to eq([ "rails-agent-harness" ])
  end

  it "ships rubocop.yml so apps can inherit_gem it" do
    expect(spec.files).to include("rubocop.yml")
  end

  it "depends on nothing at runtime" do
    # RuboCop in particular: the gem ships a YAML file, so requiring the linter
    # would force it into every consumer's bundle and fight their version pin.
    expect(spec.dependencies).to be_empty
  end

  it "excludes editor links, docs, and dev tooling" do
    expect(spec.files.grep(%r{\A\.(claude|cursor)/})).to be_empty
    expect(spec.files.grep(%r{\Adocs/})).to be_empty
    expect(spec.files.grep(%r{\Abin/})).to be_empty
    expect(spec.files.grep(%r{\Aspec/})).to be_empty
  end

  it "excludes dotfiles that would ride along with FNM_DOTMATCH" do
    expect(spec.files.grep(/\.DS_Store/)).to be_empty
  end

  it "does not define a top-level Rails constant" do
    # A gem named rails-agent-harness conventionally maps to Rails::Agent::Harness,
    # which would reopen Rails inside an application. It deliberately does not.
    expect(RailsAgentHarness.name).to eq("RailsAgentHarness")
    expect(defined?(Rails)).to be_nil
  end

  it "reports its own payload path" do
    expect(RailsAgentHarness.payload).to eq(File.join(RailsAgentHarness.root, "rails-agent-harness"))
    expect(Dir).to exist(RailsAgentHarness.payload)
  end

  describe "ruby floor" do
    # CI runs a newer Ruby than the floor, so the linter is what holds the line:
    # with TargetRubyVersion at the floor, RuboCop rejects syntax the floor
    # cannot parse. That only works while the two versions agree.
    it "lints against the same Ruby version the gemspec declares" do
      floor = spec.required_ruby_version.requirements.first.last
      target = YAML.safe_load_file(File.expand_path("../.rubocop.yml", __dir__))
                   .dig("AllCops", "TargetRubyVersion")

      expect(target.to_s).to eq(floor.segments.first(2).join("."))
    end

    it "declares the floor as a minimum, not a pin" do
      expect(spec.required_ruby_version.requirements.map(&:first)).to eq([ ">=" ])
    end
  end
end
