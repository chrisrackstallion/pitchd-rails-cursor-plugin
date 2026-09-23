# frozen_string_literal: true

require "spec_helper"
require "yaml"

# Guards the packaging contract. The payload is the whole point of this gem, so
# the things most worth asserting are that it is actually included and that the
# constants and the gemspec agree.
RSpec.describe "gem packaging" do
  let(:spec) { Gem::Specification.load(File.expand_path("../agent_harness_rails.gemspec", __dir__)) }

  it "names the payload directory identically to the constant" do
    # The gemspec hardcodes the directory rather than loading the library.
    source = File.read(File.expand_path("../agent_harness_rails.gemspec", __dir__))

    expect(source).to include(%("#{AgentHarnessRails::PAYLOAD_DIR}/**/*"))
  end

  it "ships the payload, including nested references/" do
    expect(spec.files).to include("agent_harness_rails/rules/models.mdc")
    expect(spec.files).to include("agent_harness_rails/skills/writing-tests/references/system-specs.md")
    expect(spec.files).to include("agent_harness_rails/agents/rails-reviewer.md")
  end

  it "ships the library and the executable" do
    expect(spec.files).to include("lib/agent_harness_rails.rb", "exe/agent_harness_rails")
    expect(spec.executables).to contain_exactly("agent_harness_rails")
  end

  it "ships every file the evals and guard commands need to run in a consuming app" do
    # A missing lib/ file here breaks the executable only once installed
    # elsewhere, which is an expensive place to notice it.
    root = File.expand_path("..", __dir__)

    %w[evals guard].each do |command|
      files = Dir.glob("lib/agent_harness_rails/#{command}/*.rb", base: root)

      expect(files).not_to be_empty
      expect(spec.files).to include("lib/agent_harness_rails/#{command}.rb", *files)
    end
  end

  it "ships every custom cop and the config that describes them" do
    # RuboCop loads config/default.yml by path when the department is required,
    # so leaving it out of the gem breaks cop loading in a consuming app and
    # nowhere else.
    root = File.expand_path("..", __dir__)
    cops = Dir.glob("lib/rubocop/cop/agent_harness_rails/*.rb", base: root)

    expect(cops).not_to be_empty
    expect(spec.files).to include("config/default.yml", "lib/rubocop/agent_harness_rails.rb", *cops)
  end

  it "ships every rubocop config so apps can inherit_gem them" do
    expect(spec.files).to include("rubocop.yml", "rubocop-harness.yml", "rubocop-harness-rspec.yml", "rubocop-harness-index.yml")
  end

  it "depends on nothing at runtime" do
    # RuboCop in particular. The gem ships cop files and YAML, but RuboCop is
    # what loads them, from the app's own bundle, and only when the app opts in
    # by inheriting rubocop-harness.yml. A hard dependency would force the
    # linter into every consumer's bundle and fight their version pin.
    expect(spec.dependencies).to be_empty
  end

  it "excludes editor links, docs, and dev tooling" do
    expect(spec.files.grep(%r{\A\.(claude|cursor)/})).to be_empty
    expect(spec.files.grep(%r{\Adocs/})).to be_empty
    expect(spec.files.grep(%r{\Abin/})).to be_empty
    expect(spec.files.grep(%r{\Aspec/})).to be_empty
    expect(spec.files.grep(%r{\Afixtures/})).to be_empty
  end

  it "excludes the payload paths that only develop this repo" do
    # They live in the payload so this repo's own editor links pick them up, so
    # the dotfile reject does not catch them. The gemspec repeats the list
    # literally rather than loading the library, which is what makes this assert
    # worth having: the two can silently disagree.
    source = File.read(File.expand_path("../agent_harness_rails.gemspec", __dir__))

    expect(AgentHarnessRails::DEV_ONLY).not_to be_empty
    AgentHarnessRails::DEV_ONLY.each do |relative|
      prefix = "#{AgentHarnessRails::PAYLOAD_DIR}/#{relative}/"

      expect(source).to include(prefix)
      expect(spec.files.grep(/\A#{Regexp.escape(prefix)}/)).to be_empty
      expect(Dir).to exist(File.join(AgentHarnessRails.payload, relative))
    end
  end

  it "excludes dotfiles that would ride along with FNM_DOTMATCH" do
    expect(spec.files.grep(/\.DS_Store/)).to be_empty
  end

  it "does not define a top-level Rails constant" do
    # One flat constant matching the gem name — nothing under Rails::, which
    # would reopen the Rails constant inside an application.
    expect(AgentHarnessRails.name).to eq("AgentHarnessRails")
    expect(defined?(Rails)).to be_nil
  end

  it "matches its require to its name, per the rubygems naming guide" do
    expect(spec.name).to eq("agent_harness_rails")
    expect(File).to exist(File.expand_path("../lib/#{spec.name}.rb", __dir__))
  end

  it "reports its own payload path" do
    expect(AgentHarnessRails.payload).to eq(File.join(AgentHarnessRails.root, "agent_harness_rails"))
    expect(Dir).to exist(AgentHarnessRails.payload)
  end

  describe "ruby floor" do
    # Development usually runs a newer Ruby than the floor, so the linter is what
    # holds the line: with TargetRubyVersion at the floor, RuboCop rejects syntax
    # the floor cannot parse. That only works while the two versions agree.
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
