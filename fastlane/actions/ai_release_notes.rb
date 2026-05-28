require 'open3'

module Fastlane
  module Actions
    # Generates release notes by shelling out to the local Claude Code CLI
    # (`claude -p`). Two modes:
    #   - :testers — short TestFlight changelog from commits since the last
    #     testers tag for the current marketing version.
    #   - :general — full release-notes.txt section matching the existing
    #     voice, covering all commits since the last general tag (previous
    #     minor version).
    class AiReleaseNotesAction < Action
      RELEASE_NOTES_PATH = '../release-notes.txt'.freeze
      TESTERS_CHAR_LIMIT = 1800

      def self.run(params)
        mode = params[:mode]
        version = params[:version]
        build = params[:build]

        UI.user_error!("Unknown mode: #{mode}") unless [:testers, :general].include?(mode)

        commits = gather_commits(mode, version)
        if commits.strip.empty?
          UI.important('No new commits since the last tag — nothing to summarize.')
          return mode == :testers ? "Maintenance build #{version}(#{build})." : "## v#{version}\n\nMaintenance release.\n"
        end

        prior_notes = read_prior_notes
        prompt = build_prompt(mode, version, build, commits, prior_notes)

        UI.message("Asking Claude to draft #{mode} release notes…")
        notes = run_claude(prompt)
        UI.message("Draft notes:\n#{notes}")
        notes
      end

      # ── Commit gathering ────────────────────────────────────

      def self.gather_commits(mode, version)
        range = commit_range(mode, version)
        format = '%h %s'
        if range
          `git log #{range} --no-merges --pretty=format:'#{format}'`.strip
        else
          # Fallback: most recent 50 commits if no prior tag exists.
          `git log -50 --no-merges --pretty=format:'#{format}'`.strip
        end
      end

      # Returns a "since..HEAD" rev range or nil if no prior tag exists.
      def self.commit_range(mode, version)
        candidates = case mode
                     when :testers
                       # Any tag matching the current marketing version, e.g. "1.3(*"
                       sorted_tags { |t| t.start_with?("#{version}(") }
                     when :general
                       # The last general tag (previous minor version). Strict
                       # form: tag is the bare marketing version, e.g. "1.3".
                       sorted_tags { |t| t.match?(/\A\d+\.\d+\z/) && t != version }
                     end
        last = candidates.first
        last ? "#{last}..HEAD" : nil
      end

      def self.sorted_tags
        tags = `git tag --sort=-creatordate`.split("\n").map(&:strip).reject(&:empty?)
        tags.select { |t| yield(t) }
      end

      # ── Prior notes ─────────────────────────────────────────

      def self.read_prior_notes
        File.read(RELEASE_NOTES_PATH)
      rescue Errno::ENOENT
        ''
      end

      # ── Prompt construction ─────────────────────────────────

      def self.build_prompt(mode, version, build, commits, prior_notes)
        case mode
        when :testers
          <<~PROMPT
            You are writing a TestFlight "What to Test" changelog.

            Build: #{version}(#{build})

            Rules:
            - 3-5 bullet points, one short sentence each.
            - Plain text, no markdown bullets — use "- " prefix.
            - No emoji.
            - Focus on user-visible changes; skip refactors, type fixes, internal renames.
            - Total length under #{TESTERS_CHAR_LIMIT} characters.
            - Return ONLY the bullets, no preamble or sign-off.

            Commits since last build:
            #{commits}
          PROMPT
        when :general
          <<~PROMPT
            You are adding a new release section to the GymJam release notes.

            Match the voice of the existing notes exactly. Sections use plain
            text headings (no markdown headers inside the version block), with
            bullets prefixed by "• ". Each section gets a short paragraph
            heading like "Workout flow", "Coach personalization", etc.

            Output requirements:
            - Start with "## v#{version}" on its own line.
            - One opening sentence (the headline) on the next line.
            - Then 2-5 themed sections, each with 2-6 bullets.
            - Each bullet: one sentence, ends with a period, no emoji.
            - Tight, casual but not flippant.
            - End with "---" on its own line.
            - Return ONLY the new section. Do not echo the prior notes.

            Reference — the existing release-notes.txt for voice and structure:
            ---BEGIN PRIOR NOTES---
            #{prior_notes}
            ---END PRIOR NOTES---

            Commits in v#{version} (since the previous general tag):
            #{commits}
          PROMPT
        end
      end

      # ── Claude CLI invocation ───────────────────────────────

      def self.run_claude(prompt)
        stdout, stderr, status = Open3.capture3('claude', '-p', '--max-turns', '1', stdin_data: prompt)
        UI.user_error!("claude CLI failed: #{stderr}") unless status.success?
        stdout.strip
      end

      # ── Action metadata ─────────────────────────────────────

      def self.description
        'Generates release notes via the local Claude Code CLI.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :mode, description: ':testers or :general', is_string: false, type: Symbol),
          FastlaneCore::ConfigItem.new(key: :version, description: 'Marketing version (e.g. "1.3")', type: String),
          FastlaneCore::ConfigItem.new(key: :build, description: 'Build number', type: String),
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
