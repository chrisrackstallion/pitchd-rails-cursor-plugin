# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe AgentHarnessRails::CLI do
  def run(*argv)
    out = StringIO.new
    err = StringIO.new
    status = described_class.new(argv, out: out, err: err).run
    [ status, out.string, err.string ]
  end

  describe "help" do
    # -h and --help are how scripts and CI ask for usage, so they must succeed
    # and print to stdout — an earlier version exited 1 to stderr.
    [ "-h", "--help", "help" ].each do |invocation|
      it "prints usage to stdout and exits 0 for #{invocation}" do
        status, out, err = run(invocation)

        expect(status).to eq(0)
        expect(out).to include("usage: agent_harness_rails")
        expect(err).to be_empty
      end
    end

    it "wins over a command, so `install --help` explains instead of installing" do
      status, out, = run("install", "--help", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("usage: agent_harness_rails")
      expect(Dir.children(project)).to be_empty
    end
  end

  describe "errors" do
    it "prints usage to stderr and exits 1 with no command" do
      status, out, err = run

      expect(status).to eq(1)
      expect(out).to be_empty
      expect(err).to include("usage: agent_harness_rails")
    end

    it "names an unknown command before the usage" do
      status, _, err = run("instal")

      expect(status).to eq(1)
      expect(err).to include("unknown command: instal")
    end

    it "reports an unknown option without a backtrace" do
      status, _, err = run("install", "--frobnicate")

      expect(status).to eq(1)
      expect(err).to include("error: invalid option: --frobnicate")
    end
  end

  it "prints the version" do
    status, out, = run("version")

    expect(status).to eq(0)
    expect(out.strip).to eq(AgentHarnessRails::VERSION)
  end

  it "installs and checks a project end to end" do
    status, out, = run("install", "--path", project)
    expect(status).to eq(0)
    expect(out).to include("installed")

    status, out, = run("check", "--path", project)
    expect(status).to eq(0)
    expect(out).to include("matches this gem")
  end
end
