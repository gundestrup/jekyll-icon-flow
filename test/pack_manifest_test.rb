# frozen_string_literal: true

require "test_helper"
require "jekyll/icon_flow/pack_manifest"
require "tmpdir"

class PackManifestTest < Minitest::Test
  MANIFEST = Jekyll::IconFlow::PackManifest

  SVG_A = %(<<<<SVG_A>>>>)
  SVG_B = %(<<<<SVG_B>>>>)

  def with_pack(files = { "a" => SVG_A, "b" => SVG_B })
    Dir.mktmpdir do |dir|
      files.each { |name, svg| File.write(File.join(dir, "#{name}.svg"), svg) }
      yield dir
    end
  end

  def manifest(dir, **overrides)
    MANIFEST.new({ "pack" => "test", "upstream_repo" => "org/repo",
                   "upstream_url" => "https://example.test", "license" => "MIT",
                   "version" => "1.0.0", "vendored" => "2026-01-01",
                   "icons" => MANIFEST.icon_digests(dir) }.merge(overrides))
  end

  def test_read_returns_nil_without_pack_yml
    with_pack { |dir| assert_nil MANIFEST.read(dir) }
  end

  def test_write_then_read_roundtrips_all_fields
    with_pack do |dir|
      manifest(dir, "aliases" => { "a" => "upstream-a" }).write(dir)
      read = MANIFEST.read(dir)

      assert_equal "test", read.pack
      assert_equal "org/repo", read.upstream_repo
      assert_equal "https://example.test", read.upstream_url
      assert_equal "MIT", read.license
      assert_equal "1.0.0", read.version
      assert_equal "2026-01-01", read.vendored
      assert_equal({ "a" => "upstream-a" }, read.aliases)
      assert_empty read.missing_upstream
      assert_equal MANIFEST.icon_digests(dir), read.icons
    end
  end

  def test_written_file_carries_maintenance_header
    with_pack do |dir|
      manifest(dir).write(dir)

      assert_match(/rake icons:sync/, File.read(File.join(dir, "PACK.yml")))
    end
  end

  def test_read_rejects_unparseable_yaml
    with_pack do |dir|
      File.write(File.join(dir, "PACK.yml"), "{{{ not yaml")
      assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }
    end
  end

  def test_read_rejects_non_mapping_yaml
    with_pack do |dir|
      File.write(File.join(dir, "PACK.yml"), "- just\n- a\n- list\n")
      assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }
    end
  end

  def test_validate_requires_all_fields
    with_pack do |dir|
      File.write(File.join(dir, "PACK.yml"), { "pack" => "test" }.to_yaml)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }
      assert_match(/missing keys/, error.message)
    end
  end

  def test_validate_requires_icons_map
    with_pack do |dir|
      manifest(dir, "icons" => %w[a b]).write(dir)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }
      assert_match(/icons must be/, error.message)
    end
  end

  def test_validate_rejects_path_traversal_icon_names
    with_pack do |dir|
      manifest(dir, "icons" => { "../outside" => "a" * 64 }).write(dir)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }

      assert_match(/invalid name or SHA-256/, error.message)
    end
  end

  def test_validate_rejects_malformed_icon_digests
    with_pack do |dir|
      manifest(dir, "icons" => { "a" => "not-a-digest" }).write(dir)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }

      assert_match(/invalid name or SHA-256/, error.message)
    end
  end

  def test_validate_rejects_invalid_alias_names
    with_pack do |dir|
      manifest(dir, "aliases" => { "a" => "../outside" }).write(dir)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }

      assert_match(/aliases contain an invalid/, error.message)
    end
  end

  def test_validate_rejects_invalid_missing_upstream_names
    with_pack do |dir|
      manifest(dir, "missing_upstream" => ["../outside"]).write(dir)
      error = assert_raises(Jekyll::IconFlow::Error) { MANIFEST.read(dir) }

      assert_match(/missing_upstream contains an invalid/, error.message)
    end
  end

  def test_icon_digests_ignores_non_svg_files
    with_pack do |dir|
      File.write(File.join(dir, "PACK.yml"), "pack: test")

      assert_equal %w[a b], MANIFEST.icon_digests(dir).keys
    end
  end

  def test_drift_empty_when_files_match_manifest
    with_pack do |dir|
      assert_empty manifest(dir).drift(dir)
    end
  end

  def test_drift_reports_added_removed_and_modified_files
    with_pack do |dir|
      m = manifest(dir)
      File.write(File.join(dir, "c.svg"), "new")
      File.delete(File.join(dir, "b.svg"))
      File.write(File.join(dir, "a.svg"), "tampered")

      assert_equal({ "added" => %w[c], "removed" => %w[b], "modified" => %w[a] }, m.drift(dir))
    end
  end

  def test_capture_icons_does_not_adopt_unmanaged_files
    with_pack do |dir|
      m = manifest(dir)
      File.write(File.join(dir, "unmanaged.svg"), "not from upstream")

      m.capture_icons!(dir)

      assert_equal %w[a b], m.icons.keys
      assert_equal({ "added" => %w[unmanaged] }, m.drift(dir))
    end
  end

  def test_capture_icons_preserves_digest_for_upstream_missing_file
    with_pack do |dir|
      m = manifest(dir)
      original_digest = m.icons.fetch("b")
      File.delete(File.join(dir, "b.svg"))

      m.capture_icons!(dir, preserve_missing: ["b"])

      assert_equal original_digest, m.icons.fetch("b")
      assert_equal({ "removed" => %w[b] }, m.drift(dir))
    end
  end

  def test_upstream_name_defaults_to_icon_name
    with_pack do |dir|
      assert_equal "a", manifest(dir).upstream_name("a")
    end
  end

  def test_upstream_name_follows_alias
    with_pack do |dir|
      m = manifest(dir, "aliases" => { "a" => "renamed-a" })

      assert_equal "renamed-a", m.upstream_name("a")
    end
  end
end
