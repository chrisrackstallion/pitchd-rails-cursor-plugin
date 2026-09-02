# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # What the cross-file cops share on top of RuboCop's own ProjectIndexHelp:
      # the nil guard, Rubydex's zero-based lines, the app/ <-> spec/ mirror the
      # testing rule defines, and a per-index memo so a project-wide scan runs
      # once rather than once per file.
      #
      # Every cop that includes this returns early when `project_index` is nil,
      # which is what happens whenever an app has not inherited
      # rubocop-harness-index.yml or has not installed the rubydex gem. Nothing
      # here is reached in that case, so the department loads without Rubydex.
      module IndexHelp
        include ProjectIndexHelp

        class << self
          # Keyed by graph identity: RuboCop builds one index per run, and the
          # per-file cop instances all see the same object.
          def memo
            @memo ||= {}.compare_by_identity
          end
        end

        private

        def indexed?
          !project_index.nil?
        end

        def index_memo(key)
          (IndexHelp.memo[project_index] ||= {}).fetch(key) { |k| IndexHelp.memo[project_index][k] = yield }
        end

        # Rubydex lines are zero-based; RuboCop's and a reader's are not.
        def display_line(location)
          location.start_line + 1
        end

        def covers?(location, path, line)
          same_file?(location.to_file_path, path) && (location.start_line..location.end_line).cover?(line)
        end

        # Definitions that live under the app's own app/ tree, in path order.
        def app_definitions(declaration)
          declaration.definitions
                     .select { |definition| definition.location.uri.start_with?(FILE_URI_PREFIX) }
                     .select { |definition| app_marker(definition.location.to_file_path) }
                     .sort_by { |definition| definition.location.to_file_path }
        end

        # `/x/app/jobs/foo_job.rb` -> `/x/spec/jobs/foo_job_spec.rb`, the mirror
        # agent_harness_rails/rules/testing.mdc § Test File Naming defines.
        def mirrored_spec_path(app_path)
          marker = app_marker(app_path)
          return nil unless marker

          "#{app_path[0...marker]}/spec/#{app_path[(marker + 5)..].delete_suffix('.rb')}_spec.rb"
        end

        # The directory a file's specs live under: `/x/app/policies/a.rb` ->
        # `/x/spec/policies`.
        def mirrored_spec_dir(app_path)
          marker = app_marker(app_path)
          return nil unless marker

          "#{app_path[0...marker]}/spec/#{File.dirname(app_path[(marker + 5)..])}"
        end

        # Path from the last `app/` or `spec/` segment, for messages.
        def app_relative(path)
          marker = path.rindex(%r{/(app|spec|test)/})
          marker ? path[(marker + 1)..] : path
        end

        def app_marker(path)
          path.rindex("/app/")
        end

        # Every constant reference the index resolved, grouped by the name of
        # the declaration it points at, as the set of files it appears in. A
        # reference to a singleton (`Article::<Article>`, from `Article.new`)
        # counts for `Article`.
        def referencing_files
          index_memo(:referencing_files) do
            project_index.constant_references.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |reference, files|
              next unless reference.is_a?(Rubydex::ResolvedConstantReference)
              next unless reference.location.uri.start_with?(FILE_URI_PREFIX)

              name = reference.declaration.name.sub(/::<[^>]+>\z/, "")
              files[name] << reference.location.to_file_path
            end
          end
        end

        # Zero-based lines, per file, of every call to one of `names`.
        def call_lines(names)
          index_memo([ :call_lines, names ]) do
            project_index.method_references.each_with_object(Hash.new { |h, k| h[k] = [] }) do |reference, lines|
              next unless names.include?(reference.name.delete_suffix("()"))
              next unless reference.location.uri.start_with?(FILE_URI_PREFIX)

              lines[reference.location.to_file_path] << reference.location.start_line
            end
          end
        end

        # Whether any of the calls named in `names` sits inside the body of
        # `method`, wherever that body is defined.
        def calls_within?(method, names)
          lines = call_lines(names)

          method.definitions.any? do |definition|
            location = definition.location
            next false unless location.uri.start_with?(FILE_URI_PREFIX)

            lines[location.to_file_path].any? { |line| (location.start_line..location.end_line).cover?(line) }
          end
        end
      end
    end
  end
end
