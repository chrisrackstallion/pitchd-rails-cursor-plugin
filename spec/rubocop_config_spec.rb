# frozen_string_literal: true

require "spec_helper"

# The shipped RuboCop configs name well over a hundred cops. RuboCop treats an
# unknown cop name in a config as a hard error, so a cop renamed or removed
# upstream does not degrade — it stops the consuming app's linter dead. Nothing
# in this repo would otherwise notice, because the harness itself is not a Rails
# app and never runs these cops against Rails code.
#
# So: assert every name resolves. A rename upstream fails here, on a branch,
# instead of in someone else's CI.

# Every plugin the shipped configs name, required explicitly rather than relying
# on Bundler happening to have made them reachable through another require.
require "rubocop-rails"
require "rubocop-rspec"
require "rubocop-rspec_rails"
require "rubocop-capybara"
require "rubocop-factory_bot"
require "rubocop/agent_harness_rails"
require "open3"

RSpec.describe "shipped RuboCop configs" do
  def root
    File.expand_path("..", __dir__)
  end

  def load_config(file)
    YAML.safe_load_file(File.join(root, file), aliases: true)
  end

  def cop_names(file)
    load_config(file).keys.grep(%r{\A[A-Z]\w*/})
  end

  def registry
    @registry ||= RuboCop::Cop::Registry.global.cops.map(&:cop_name)
  end

  [ "rubocop-harness.yml", "rubocop-harness-rspec.yml", "rubocop-harness-index.yml" ].each do |file|
    describe file do
      it "names only cops that exist in the installed RuboCop and plugins" do
        expect(cop_names(file) - registry).to be_empty,
                                              "unknown cops would abort a consuming app's RuboCop run"
      end

      it "enables every cop it names" do
        config = load_config(file)

        expect(cop_names(file).reject { |name| config[name]["Enabled"] == true }).to be_empty
      end

      it "names each cop once" do
        declared = File.read(File.join(root, file), encoding: "UTF-8").scan(/^([A-Z]\w*\/[\w\/]+):$/).flatten

        expect(declared).to eq(declared.uniq)
      end

      it "declares where its cops come from" do
        # Without this the file only works when something else in the app's
        # inheritance chain happens to have loaded the plugin or department
        # already.
        config = load_config(file)

        expect(Array(config["plugins"]) + Array(config["require"])).not_to be_empty
      end
    end
  end

  describe "the custom department" do
    it "ships a default for every cop in the AgentHarnessRails namespace" do
      defaults = load_config("config/default.yml")
      loaded = registry.grep(%r{\AAgentHarnessRails/})

      expect(loaded).not_to be_empty
      expect(loaded - defaults.keys).to be_empty, "a cop with no entry in config/default.yml has no Include or Description"
    end

    it "points every cop at the rule file it enforces" do
      defaults = load_config("config/default.yml").reject { |name, _| name == "AgentHarnessRails" }

      defaults.each do |name, settings|
        reference = settings["Reference"]

        expect(reference).to be_a(String), "#{name} has no Reference"
        expect(File).to exist(File.join(root, reference)), "#{name} references #{reference}, which does not exist"
      end
    end

    it "scopes every cop to the paths its rule applies to" do
      defaults = load_config("config/default.yml").reject { |name, _| name == "AgentHarnessRails" }

      expect(defaults.reject { |_, settings| settings["Include"] }.keys).to be_empty
    end
  end

  describe "loading it the way an app does" do
    # Writes the app-side .rubocop.yml and asks RuboCop to load it. Anything
    # RuboCop rejects — bad YAML, an unknown cop, a malformed Categories map —
    # surfaces here rather than in a consuming app's first lint run.
    #
    # inherit_gem rather than inherit_from with a path: that is the mechanism the
    # README documents, and it resolves the gem by name through RubyGems, so a
    # file this repo has but the gem does not ship fails here.
    def app_config(extra = "", files: [ "rubocop-harness.yml" ])
      path = File.join(project, ".rubocop.yml")
      File.write(path, <<~YAML)
        inherit_gem:
          agent_harness_rails:
        #{files.map { |file| "    - #{file}" }.join("\n")}
        AllCops:
          NewCops: disable
        #{extra}
      YAML
      RuboCop::ConfigLoader.configuration_from_file(path)
    end

    it "resolves through inherit_gem, the way the README tells apps to configure it" do
      # Nothing else checks the documented path: RuboCop looks the gem up by name
      # through RubyGems and reads the config out of its gem_dir, so a config file
      # the gem does not actually ship fails here rather than in a consuming app.
      #
      # Deliberately no assertion on the gem's file manifest — that is
      # spec/gem_spec.rb's job, against the gemspec. Reading `.files` off a
      # resolved spec gives different answers for a path source and an installed
      # gem, so an assertion here would break for reasons that have nothing to
      # do with the config.
      expect { app_config }.not_to raise_error
      expect(app_config.for_cop("AgentHarnessRails/ServiceObject")["Enabled"]).to be(true)
    end

    it "resolves the rspec layer through inherit_gem too" do
      config = app_config("", files: [ "rubocop-harness.yml", "rubocop-harness-rspec.yml" ])

      expect(config.for_cop("RSpec/AnyInstance")["Enabled"]).to be(true)
      expect(config.for_cop("AgentHarnessRails/SpecSleep")["Enabled"]).to be(true)
    end

    it "resolves the index layer through inherit_gem, turning the index and its cops on together" do
      config = app_config("", files: [ "rubocop-harness.yml", "rubocop-harness-index.yml" ])

      expect(config.for_all_cops["UseProjectIndex"]).to be(true)
      expect(config.for_cop("AgentHarnessRails/RouteWithoutAction")["Enabled"]).to be(true)
      expect(config.for_cop("Naming/PredicatePrefix")["Enabled"]).to be(true)
    end

    it "leaves the cross-file cops off without the index layer" do
      # They would do nothing anyway; off keeps `--show-cops` honest about it.
      expect(app_config.for_cop("AgentHarnessRails/RouteWithoutAction")["Enabled"]).to be(false)
      expect(app_config.for_cop("AgentHarnessRails/UnreferencedMethod")["Enabled"]).to be(false)
    end

    it "resolves without error and enables both the borrowed and the custom cops" do
      config = app_config

      expect(config.for_cop("Rails/DefaultScope")["Enabled"]).to be(true)
      expect(config.for_cop("Layout/ClassStructure")["Enabled"]).to be(true)
      expect(config.for_cop("AgentHarnessRails/ServiceObject")["Enabled"]).to be(true)
    end

    it "lets the app turn a single cop off" do
      config = app_config("Layout/ClassStructure:\n  Enabled: false\n")

      expect(config.for_cop("Layout/ClassStructure")["Enabled"]).to be(false)
      expect(config.for_cop("Rails/DefaultScope")["Enabled"]).to be(true), "opting out of one cop must not disturb the rest"
    end

    it "lets the app turn the whole custom department off in one line" do
      config = app_config("AgentHarnessRails:\n  Enabled: false\n")

      expect(config.for_cop("AgentHarnessRails/ServiceObject")["Enabled"]).to be(false)
      expect(config.for_cop("Rails/DefaultScope")["Enabled"]).to be(true), "the department switch must not reach the borrowed cops"
    end

    it "orders model macros the way the models rule documents" do
      order = app_config.for_cop("Layout/ClassStructure")["ExpectedOrder"]

      expect(order.index("association")).to be < order.index("validation")
      expect(order.index("validation")).to be < order.index("callback")
      expect(order.index("callback")).to be < order.index("scope")
      expect(order.index("scope")).to be < order.index("public_methods")
    end

    it "orders controller actions the way the controllers rule documents" do
      # RuboCop's own default differs (new/edit/create/update), so this is an
      # override that must not drift from the example it follows.
      rule = File.read(File.join(root, "agent_harness_rails/rules/controllers.mdc"), encoding: "UTF-8")
      documented = app_config.for_cop("Rails/ActionOrder")["ExpectedOrder"]

      # Only § Controller Structure: that is the example the override follows, and
      # the rule's other snippets deliberately show actions out of order.
      structure = rule[/^## Controller Structure$.*?(?=^## )/m]

      expect(documented).to eq(%w[index show new create edit update destroy])
      expect(structure.scan(/^  def (\w+)$/).flatten & documented).to eq(documented)
    end
  end

  describe "the index layer, end to end" do
    # Unit specs hand each cop a graph directly. This is the only place that
    # proves the runner builds one from `UseProjectIndex`, passes it to the
    # department, and that each cop's Include reaches the file it should —
    # against a Rails-shaped tree with one deliberate offence per cop
    # (fixtures/index_app/README.md).
    def fixture
      File.join(root, "fixtures", "index_app")
    end

    def offenses(*args)
      # --ignore-parent-exclusion: RuboCop otherwise applies this repo's own
      # AllCops/Exclude, which hides fixtures/ from its lint, to the fixture too.
      output, status = Dir.chdir(fixture) do
        Open3.capture2("bundle", "exec", "rubocop", "--format", "json", "--cache", "false",
                       "--ignore-parent-exclusion", *args)
      end
      expect(status.exitstatus).to eq(1), "expected offences, got exit #{status.exitstatus}: #{output}"

      JSON.parse(output.force_encoding("UTF-8")).fetch("files").flat_map do |file|
        file.fetch("offenses").map { |offense| [ offense.fetch("cop_name"), file.fetch("path") ] }
      end
    end

    it "reports exactly the deliberate offences, each in the file its rule points at" do
      # An exact match: with omakase inherited the fixture is otherwise clean, so
      # a cop firing where it should not shows up here as much as one going quiet.
      expect(offenses).to match_array([
        [ "AgentHarnessRails/RouteWithoutAction", "config/routes.rb" ],
        [ "AgentHarnessRails/RouteWithoutAction", "config/routes.rb" ],
        [ "AgentHarnessRails/EnqueueOutsideCommit", "app/models/concerns/publishable.rb" ],
        [ "AgentHarnessRails/ExecutedOutsideOwnSpec", "spec/models/article_spec.rb" ],
        [ "AgentHarnessRails/MissingOwnSpec", "app/models/concerns/publishable.rb" ],
        [ "AgentHarnessRails/MissingOwnSpec", "app/policies/article_policy.rb" ],
        [ "AgentHarnessRails/MailerWithoutPreview", "app/mailers/user_mailer.rb" ],
        [ "AgentHarnessRails/MisfiledSpec", "spec/models/account_onboarding_spec.rb" ]
      ])
    end

    it "runs the dead-method sweep only when asked, and finds only the dead method" do
      # `byline` is called from a template, `publish` from a spec, `notify_later`
      # by symbol; `legacy_slug` by nothing.
      reported = offenses("--only", "AgentHarnessRails/UnreferencedMethod")

      expect(reported).to eq([ [ "AgentHarnessRails/UnreferencedMethod", "app/models/article.rb" ] ])
    end
  end

  it "keeps the thin omakase layer free of cop settings" do
    # rubocop.yml promises never to restate or contradict omakase; enforcement
    # belongs in the opt-in files, which apps inherit separately.
    expect(cop_names("rubocop.yml")).to be_empty
  end
end
