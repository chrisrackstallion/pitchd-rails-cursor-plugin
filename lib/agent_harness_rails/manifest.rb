# frozen_string_literal: true

require "digest"
require "json"

module AgentHarnessRails
  # Record of which payload files this gem owns in a consuming app, and the
  # checksum each had when written.
  #
  # Ownership is needed because gem-owned and app-authored skills share one flat
  # directory — Claude Code does not recurse into subdirectories, so a vendored
  # subtree the installer could simply delete is not an option. The manifest is
  # what lets `install` replace its own files, leave locally edited ones alone,
  # and refuse to overwrite anything the app wrote.
  class Manifest
    FILENAME = ".manifest.json"
    INSTALLER_KEY = "rails-agent-harness"

    attr_reader :version, :owns

    def self.path_within(payload_dir)
      File.join(payload_dir, FILENAME)
    end

    def self.digest(path)
      "sha256:#{Digest::SHA256.file(path).hexdigest}"
    end

    # Reads a manifest, or returns an empty one when the app has none yet.
    def self.load(payload_dir)
      path = path_within(payload_dir)
      return new(version: nil, owns: {}) unless File.exist?(path)

      data = JSON.parse(File.read(path)).fetch(INSTALLER_KEY, {})
      new(version: data["version"], owns: data["owns"] || {})
    rescue JSON::ParserError => e
      raise Error, "#{path} is not valid JSON (#{e.message})"
    end

    def initialize(version:, owns:)
      @version = version
      @owns = owns
    end

    def owns?(relative_path)
      owns.key?(relative_path)
    end

    # True when the file on disk still matches what this gem wrote, i.e. nobody
    # has edited it locally.
    def unmodified?(relative_path, absolute_path)
      return false unless owns?(relative_path)
      return false unless File.exist?(absolute_path)

      owns[relative_path] == self.class.digest(absolute_path)
    end

    # Written to a temp file and renamed, so a crash mid-write cannot leave a
    # half-written manifest that `load` would then reject as invalid JSON.
    def write(payload_dir)
      body = { INSTALLER_KEY => { "version" => version, "owns" => owns.sort.to_h } }
      path = path_within(payload_dir)
      File.write("#{path}.tmp", "#{JSON.pretty_generate(body)}\n")
      File.rename("#{path}.tmp", path)
    end

    def path_within(payload_dir)
      self.class.path_within(payload_dir)
    end
  end
end
