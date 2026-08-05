require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fileutils'
require 'json'
require 'tmpdir'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    # Uploads a directory of snapshot images to Sentry Snapshots: refuses
    # partial runs that would corrupt the main baseline, uploads only images
    # that changed vs that baseline (Sentry bills per image), and falls back
    # to a full upload when no baseline exists or the diff fails.
    class SentrySnapshotsHelper
      # layout_changed is sentry-cli's status for an odiff dimension change; it is
      # a real change and must be uploaded like changed/added, not skipped.
      CHANGED_STATUSES = %w[changed layout_changed added].freeze
      def self.upload_snapshots(export_dir:, app_id:, sentry_cli:, min_count:, main_branch:, current_branch:)
        ensure_min_count!(export_dir, min_count)
        ensure_no_partial_run!(export_dir, app_id, sentry_cli, main_branch) if current_branch == main_branch

        upload_dir, all_names_file = select_changed_snapshots(export_dir, app_id, sentry_cli, main_branch)
        if upload_dir
          changed = png_count(upload_dir)
          # sentry-cli's `snapshots upload` early-returns on an empty directory
          # without creating a snapshot (and never reads --all-image-file-names-file),
          # so a zero-change selective upload would leave the PR with no snapshot at
          # all. Nothing changed vs the baseline, so there is nothing to diff: skip.
          # TODO: drop this skip once sentry-cli can record an all-unchanged snapshot
          # from a full name list (upstream issue pending).
          if changed.zero?
            UI.success("No snapshots changed vs the #{main_branch} baseline; skipping upload (nothing to diff).")
            return
          end
          UI.success("Selective upload: #{changed} changed images (of #{png_count(export_dir)})")
          Actions.sh(sentry_cli, "snapshots", "upload", "--app-id", app_id,
                     "--selective", "--all-image-file-names-file", all_names_file, upload_dir)
        else
          Actions.sh(sentry_cli, "snapshots", "upload", "--app-id", app_id, export_dir)
        end
      end

      def self.ensure_min_count!(export_dir, min_count)
        image_count = png_count(export_dir)
        return if image_count >= min_count

        UI.user_error!("Only #{image_count} snapshots were generated in #{export_dir} (expected at least #{min_count}). " \
                       "A partial run uploaded as a baseline would mark the missing snapshots as removed on every open PR.")
      end

      # Only the main branch's upload replaces the shared baseline; a partial
      # upload from any other branch affects nothing but that PR's own diff.
      def self.ensure_no_partial_run!(export_dir, app_id, sentry_cli, main_branch)
        return if ENV["SNAPSHOT_COUNT_OVERRIDE"] == "1"

        base_dir = File.join(Dir.mktmpdir("snapshots"), "baseline-count")
        begin
          download_baseline(base_dir, app_id, sentry_cli, main_branch)
        rescue StandardError => e
          UI.user_error!("Could not download the baseline for the partial-run check (#{e.message}). " \
                         "Refusing to upload unverified; set SNAPSHOT_COUNT_OVERRIDE=1 to bypass (e.g. the first-ever upload).")
        end
        baseline = png_count(base_dir)
        return if baseline.zero?

        generated = png_count(export_dir)
        return if generated >= (baseline * 0.9).floor

        UI.user_error!("Generated #{generated} snapshots; the #{main_branch} baseline has #{baseline}. " \
                       "Refusing to upload what looks like a partial run. Set SNAPSHOT_COUNT_OVERRIDE=1 for intentional removals.")
      end

      # Stages only changed/added images (with their .json sidecars, which
      # carry display names and tags) for a --selective upload. Returns
      # [upload_dir, all_names_file], or nil on any failure (callers then
      # full-upload).
      def self.select_changed_snapshots(export_dir, app_id, sentry_cli, main_branch)
        work_dir = Dir.mktmpdir("snapshots")
        base_dir = File.join(work_dir, "base")
        download_baseline(base_dir, app_id, sentry_cli, main_branch)
        return nil if png_count(base_dir).zero?

        diff_json = Actions.sh(sentry_cli, "snapshots", "diff", base_dir, export_dir, log: false)
        results = JSON.parse(diff_json[/\{.*\}/m])
        log_diff_summary(results["summary"])
        # The diff reports one entry per image with a status; there are no
        # top-level changed/added arrays.
        changed = (results["images"] || [])
                  .select { |image| CHANGED_STATUSES.include?(image["status"]) }
                  .map { |image| image["name"] }

        upload_dir = File.join(work_dir, "changed")
        stage_images(changed, export_dir, upload_dir)

        # The complete name list lets Sentry distinguish skipped from removed.
        all_names_file = File.join(work_dir, "snapshot-names.txt")
        all_names = Dir.glob("#{export_dir}/**/*.png").map { |f| f.delete_prefix("#{export_dir}/") }.sort
        File.write(all_names_file, "#{all_names.join("\n")}\n")

        [upload_dir, all_names_file]
      rescue StandardError => e
        UI.important("Selective snapshot diff failed (#{e.message}); falling back to full upload")
        nil
      end

      # Relative paths throughout, so nested exports survive the copy. Each
      # image's .json sidecar (display name, tags) rides along when present.
      def self.stage_images(changed, export_dir, upload_dir)
        FileUtils.mkdir_p(upload_dir)
        changed.each do |name|
          relative = name.to_s
          [relative, relative.sub(/\.png\z/, ".json")].each do |staged_relative|
            source = File.join(export_dir, staged_relative)
            next unless File.exist?(source)

            destination = File.join(upload_dir, staged_relative)
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(source, destination)
          end
        end
      end

      def self.log_diff_summary(summary)
        return if summary.nil?

        UI.message("Snapshot diff vs baseline: #{summary['changed']} changed, #{summary['added']} added, " \
                   "#{summary['unchanged']} unchanged, #{summary['removed']} removed")
      end

      def self.download_baseline(base_dir, app_id, sentry_cli, main_branch)
        FileUtils.rm_rf(base_dir)
        Actions.sh(sentry_cli, "snapshots", "download", "--app-id", app_id, "--branch", main_branch, "--output", base_dir, log: false)
      end

      def self.png_count(dir)
        Dir.glob("#{dir}/**/*.png").count
      end
    end
  end
end
