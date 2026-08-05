require 'fileutils'
require 'tmpdir'

describe Fastlane::Helper::SentrySnapshotsHelper do
  let(:helper) { described_class }
  let(:cli) { '/fake/sentry-cli' }
  let(:app_id) { 'com.example.app' }
  let(:export_dir) { Dir.mktmpdir('export') }

  # Real output shape of `sentry-cli snapshots diff` (3.6.1): a summary block
  # plus one entry per image with a status. Trailing human summary included.
  let(:diff_output) do
    <<~JSON
      {
        "base_dir": "base",
        "head_dir": "head",
        "threshold": 0.01,
        "summary": { "total": 4, "changed": 2, "unchanged": 1, "added": 1, "removed": 0 },
        "images": [
          { "name": "images/unchanged.png", "status": "unchanged" },
          { "name": "images/changed.png", "status": "changed", "diff_percentage": 12.3 },
          { "name": "images/layout.png", "status": "layout_changed", "diff_percentage": 40.0 },
          { "name": "images/added.png", "status": "added" }
        ]
      }

      Summary: 4 total, 2 changed, 1 unchanged, 1 added, 0 removed
    JSON
  end

  def create_export_image(name, sidecar: false)
    path = File.join(export_dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, 'png')
    File.write(path.sub(/\.png\z/, '.json'), '{}') if sidecar
  end

  after { FileUtils.rm_rf(export_dir) }

  describe '.ensure_min_count!' do
    it 'fails when fewer images than the minimum were generated' do
      create_export_image('images/a.png')
      expect do
        helper.ensure_min_count!(export_dir, 2)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Only 1 snapshots/)
    end

    it 'passes at or above the minimum' do
      create_export_image('images/a.png')
      expect { helper.ensure_min_count!(export_dir, 1) }.not_to raise_error
    end
  end

  describe '.select_changed_snapshots' do
    before do
      create_export_image('images/unchanged.png', sidecar: true)
      create_export_image('images/changed.png', sidecar: true)
      create_export_image('images/layout.png', sidecar: true)
      create_export_image('images/added.png', sidecar: true)

      allow(Fastlane::Actions).to receive(:sh) do |*args, **_kwargs|
        if args.include?('download')
          base_dir = args[args.index('--output') + 1]
          FileUtils.mkdir_p(File.join(base_dir, 'images'))
          File.write(File.join(base_dir, 'images', 'unchanged.png'), 'png')
          ''
        elsif args.include?('diff')
          diff_output
        else
          ''
        end
      end
    end

    it 'logs the diff breakdown' do
      expect(Fastlane::UI).to receive(:message).with('Snapshot diff vs baseline: 2 changed, 1 added, 1 unchanged, 0 removed')
      helper.select_changed_snapshots(export_dir, app_id, cli, 'main')
    end

    it 'stages changed, layout-changed, and added images with their sidecars' do
      upload_dir, all_names_file = helper.select_changed_snapshots(export_dir, app_id, cli, 'main')

      staged = Dir.glob("#{upload_dir}/**/*").select { |f| File.file?(f) }.map { |f| f.delete_prefix("#{upload_dir}/") }
      expect(staged.sort).to eq([
                                  'images/added.json',
                                  'images/added.png',
                                  'images/changed.json',
                                  'images/changed.png',
                                  'images/layout.json',
                                  'images/layout.png'
                                ])
      expect(File.read(all_names_file).split("\n").sort).to eq([
                                                                 'images/added.png',
                                                                 'images/changed.png',
                                                                 'images/layout.png',
                                                                 'images/unchanged.png'
                                                               ])
    end

    it 'returns nil when there is no baseline' do
      allow(Fastlane::Actions).to receive(:sh).and_return('')
      expect(helper.select_changed_snapshots(export_dir, app_id, cli, 'main')).to be_nil
    end

    it 'returns nil when the diff fails' do
      allow(Fastlane::Actions).to receive(:sh) do |*args, **_kwargs|
        if args.include?('download')
          base_dir = args[args.index('--output') + 1]
          FileUtils.mkdir_p(base_dir)
          File.write(File.join(base_dir, 'base.png'), 'png')
          ''
        else
          raise StandardError, 'diff exploded'
        end
      end
      expect(helper.select_changed_snapshots(export_dir, app_id, cli, 'main')).to be_nil
    end
  end

  describe '.ensure_no_partial_run!' do
    it 'is skipped by SNAPSHOT_COUNT_OVERRIDE' do
      ENV['SNAPSHOT_COUNT_OVERRIDE'] = '1'
      expect(Fastlane::Actions).not_to receive(:sh)
      helper.ensure_no_partial_run!(export_dir, app_id, cli, 'main')
    ensure
      ENV.delete('SNAPSHOT_COUNT_OVERRIDE')
    end

    it 'fails when generated count is well below the baseline' do
      create_export_image('images/a.png')
      allow(Fastlane::Actions).to receive(:sh) do |*args, **_kwargs|
        base_dir = args[args.index('--output') + 1]
        FileUtils.mkdir_p(base_dir)
        10.times { |i| File.write(File.join(base_dir, "b#{i}.png"), 'png') }
        ''
      end
      expect do
        helper.ensure_no_partial_run!(export_dir, app_id, cli, 'main')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /partial run/)
    end

    it 'fails closed when the baseline download errors' do
      allow(Fastlane::Actions).to receive(:sh).and_raise(StandardError, 'network down')
      expect do
        helper.ensure_no_partial_run!(export_dir, app_id, cli, 'main')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Refusing to upload unverified/)
    end
  end

  describe '.upload_snapshots' do
    it 'full-uploads on a branch with no baseline' do
      create_export_image('images/a.png')
      allow(Fastlane::Actions).to receive(:sh).and_return('')
      expect(Fastlane::Actions).to receive(:sh).with(cli, 'snapshots', 'upload', '--app-id', app_id, export_dir)

      helper.upload_snapshots(
        export_dir: export_dir, app_id: app_id, sentry_cli: cli,
        min_count: 1, main_branch: 'main', current_branch: 'feature'
      )
    end

    # sentry-cli no-ops on an empty upload dir, so a zero-change selective upload
    # would produce no snapshot at all; the lane skips it instead.
    it 'skips the upload when nothing changed vs the baseline' do
      create_export_image('images/a.png', sidecar: true)
      upload_called = false
      allow(Fastlane::Actions).to receive(:sh) do |*args, **_kwargs|
        upload_called = true if args.include?('upload')
        if args.include?('download')
          base_dir = args[args.index('--output') + 1]
          FileUtils.mkdir_p(File.join(base_dir, 'images'))
          File.write(File.join(base_dir, 'images', 'a.png'), 'png')
          ''
        elsif args.include?('diff')
          '{ "summary": { "total": 1, "changed": 0, "unchanged": 1, "added": 0, "removed": 0 }, ' \
            '"images": [ { "name": "images/a.png", "status": "unchanged" } ] }'
        else
          ''
        end
      end

      helper.upload_snapshots(
        export_dir: export_dir, app_id: app_id, sentry_cli: cli,
        min_count: 1, main_branch: 'main', current_branch: 'feature'
      )
      expect(upload_called).to be(false)
    end
  end
end
