# frozen_string_literal: true

require "spec_helper"
require "open3"

# The other specs drive the libraries in-process. These drive the `exe/` shim as
# a real subprocess, because that is the only thing in-process specs cannot cover:
# a shim requiring a path that does not exist, or an executable bit that never got
# set, fails identically to a working one until someone actually runs it.
#
# Deliberately thin. Behaviour — which findings, which messages, which exit code
# for which tree — belongs in spec/evals_spec.rb, where each example builds the
# tree it needs and says what it expects.
RSpec.describe "executables" do
  def root
    File.expand_path("..", __dir__)
  end

  def run(*argv)
    Open3.capture2e({ "RUBYOPT" => nil }, RbConfig.ruby, "-I#{File.join(root, 'lib')}", *argv, chdir: root)
  end

  describe "exe/agent_harness_rails" do
    it "is executable" do
      expect(File).to be_executable(File.join(root, "exe/agent_harness_rails"))
    end

    it "loads and reports its version" do
      output, status = run("exe/agent_harness_rails", "version")

      expect(status).to be_success, output
      expect(output.strip).to eq(AgentHarnessRails::VERSION)
    end

    it "runs evals green against the fixture app" do
      output, status = run("exe/agent_harness_rails", "evals", "--path", "fixtures/primitives_app")

      expect(status).to be_success, output
      expect(output).to include("1 capability inspected", "4 clauses", "no offences")
    end

    # Also the one place a nested project directory is exercised: the fixture app
    # is a subdirectory of this repo, so git resolves its paths relative to that
    # directory rather than to the repo root. Getting that wrong would produce an
    # empty baseline and a confident all-clear.
    it "runs guard against the fixture app inside this repository" do
      output, status = run("exe/agent_harness_rails", "guard", "--path", "fixtures/primitives_app")

      expect(status).to be_success, output
      expect(output).to include("compared against")
    end

    it "reports a tree evals cannot find rather than crashing" do
      output, status = run("exe/agent_harness_rails", "evals", "--path", ".")

      expect(status).not_to be_success
      expect(output).to start_with("error: no capability docs")
    end
  end
end
