# frozen_string_literal: true

require "test_helper"
require "jekyll/icon_flow/pack_sync"
require "tmpdir"

class PackSyncTest < Minitest::Test
  SYNC = Jekyll::IconFlow::PackSync
  MANIFEST = Jekyll::IconFlow::PackManifest

  REPO = "org/pack"
  RELEASE_JSON = '{"tag_name": "2.0.0"}'

  def write_pack(dir, icons, manifest_icons: nil)
    icons.each { |name, svg| File.write(File.join(dir, "#{name}.svg"), svg) }
    MANIFEST.new(
      "pack" => "test", "upstream_repo" => REPO,
      "upstream_url" => "https://example.test", "license" => "MIT",
      "version" => "1.0.0", "vendored" => "2026-01-01",
      "aliases" => manifest_icons&.fetch(:aliases, nil) || {},
      "missing_upstream" => manifest_icons&.fetch(:missing_upstream, nil) || [],
      "icons" => manifest_icons&.fetch(:digests, nil) || MANIFEST.icon_digests(dir)
    ).write(dir)
  end

  def with_pack(icons:, manifest_icons: nil)
    Dir.mktmpdir do |dir|
      write_pack(dir, icons, manifest_icons: manifest_icons)
      yield dir
    end
  end

  # url => canned body, or an Exception instance to raise
  def fetcher(mapping)
    lambda do |url|
      body = mapping.fetch(url) { raise "unexpected fetch #{url}" }
      raise body if body.is_a?(Exception)

      body
    end
  end

  def icon_url(name, tag: "2.0.0")
    SYNC.raw_icon_url(REPO, tag, name)
  end

  def release_fetcher(extra = {})
    fetcher({ "#{SYNC::API}/repos/#{REPO}/releases/latest" => RELEASE_JSON }.merge(extra))
  end

  def test_latest_version_parses_tag_name
    assert_equal "2.0.0", SYNC.latest_version(REPO, fetcher: release_fetcher)
  end

  def test_latest_version_raises_on_missing_tag
    error = assert_raises(Jekyll::IconFlow::Error) do
      SYNC.latest_version(REPO, fetcher: ->(_u) { "{}" })
    end
    assert_match(/no tag_name/, error.message)
  end

  def test_latest_version_raises_on_bad_json
    assert_raises(Jekyll::IconFlow::Error) do
      SYNC.latest_version(REPO, fetcher: ->(_u) { "not json" })
    end
  end

  def test_latest_version_rejects_non_object_response
    error = assert_raises(Jekyll::IconFlow::Error) do
      SYNC.latest_version(REPO, fetcher: ->(_u) { "[]" })
    end
    assert_match(/expected an object/, error.message)
  end

  def test_raw_icon_url_layout
    assert_equal "https://raw.githubusercontent.com/org/pack/1.2.3/icons/a.svg",
                 SYNC.raw_icon_url("org/pack", "1.2.3", "a")
  end

  def test_raw_icon_url_rejects_path_components
    assert_raises(Jekyll::IconFlow::Error) do
      SYNC.raw_icon_url(REPO, "2.0.0", "../outside")
    end
  end

  def test_each_finds_only_managed_packs
    Dir.mktmpdir do |root|
      Dir.mkdir(File.join(root, "managed"))
      Dir.mkdir(File.join(root, "unmanaged"))
      MANIFEST.new("pack" => "m", "upstream_repo" => REPO,
                   "upstream_url" => "https://example.test", "license" => "MIT",
                   "version" => "1.0.0", "vendored" => "2026-01-01",
                   "icons" => {}).write(File.join(root, "managed"))

      assert_equal [File.join(root, "managed")], SYNC.each(root).map(&:dir)
    end
  end

  def test_check_reports_behind_pack
    with_pack(icons: { "a" => "old" }) do |dir|
      report = SYNC.new(dir, fetcher: release_fetcher).check

      assert_equal "1.0.0", report["current"]
      assert_equal "2.0.0", report["latest"]
      assert report["behind"]
      assert_empty report["drift"]
    end
  end

  def test_check_reports_current_pack
    with_pack(icons: { "a" => "x" }) do |dir|
      f = release_fetcher("#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"1.0.0"}')

      refute SYNC.new(dir, fetcher: f).check["behind"]
    end
  end

  def test_check_fetches_latest_release_once
    with_pack(icons: { "a" => "x" }) do |dir|
      calls = 0
      f = lambda do |_url|
        calls += 1
        '{"tag_name":"1.0.0"}'
      end

      SYNC.new(dir, fetcher: f).check

      assert_equal 1, calls
    end
  end

  def test_behind_survives_unparseable_versions
    with_pack(icons: { "a" => "x" }) do |dir|
      f = release_fetcher("#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"weekly"}')

      assert_predicate SYNC.new(dir, fetcher: f), :behind?
    end
  end

  def test_sync_rewrites_changed_icons_and_manifest
    with_pack(icons: { "a" => "old-a", "b" => "same-b" }) do |dir|
      f = release_fetcher(icon_url("a") => "new-a", icon_url("b") => "same-b")
      result = SYNC.new(dir, fetcher: f).sync

      assert_equal "new-a", File.read(File.join(dir, "a.svg"))
      assert_equal "same-b", File.read(File.join(dir, "b.svg"))
      assert_equal %w[a], result["updated"]
      assert_equal 2, result["icons"]
      assert_equal "2.0.0", result["version"]
      assert_empty result["missing_upstream"]

      read = MANIFEST.read(dir)

      assert_equal "2.0.0", read.version
      assert_match(/\A\d{4}-\d{2}-\d{2}\z/, read.vendored)
      assert_equal MANIFEST.icon_digests(dir), read.icons
      assert_empty read.drift(dir)
    end
  end

  def test_sync_keeps_icons_missing_upstream
    with_pack(icons: { "gone" => "local-copy" }) do |dir|
      f = release_fetcher(icon_url("gone") => Jekyll::IconFlow::Error.new("HTTP 404 fetching x"))
      result = SYNC.new(dir, fetcher: f).sync

      assert_equal "local-copy", File.read(File.join(dir, "gone.svg"))
      assert_equal %w[gone], result["missing_upstream"]
      assert_equal %w[gone], MANIFEST.read(dir).missing_upstream
    end
  end

  def test_sync_keeps_missing_upstream_status_current_until_resolved
    with_pack(icons: { "gone" => "local-copy" },
              manifest_icons: { missing_upstream: ["gone"] }) do |dir|
      fetcher = release_fetcher(
        "#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"1.0.0"}'
      )
      report = SYNC.new(dir, fetcher: fetcher).check

      refute report["behind"]
      assert_equal %w[gone], report["missing_upstream"]
      assert_equal %w[gone], SYNC.new(dir, fetcher: fetcher).check["missing_upstream"]
    end
  end

  def test_sync_does_not_update_manifest_when_pack_is_unchanged
    with_pack(icons: { "a" => "same" }) do |dir|
      path = File.join(dir, "PACK.yml")
      before = File.binread(path)
      f = fetcher(icon_url("a", tag: "1.0.0") => "same")

      result = SYNC.new(dir, fetcher: f).sync(tag: "1.0.0")

      assert_empty result["updated"]
      assert_equal before, File.binread(path)
    end
  end

  def test_sync_does_not_adopt_unmanaged_local_icons
    with_pack(icons: { "a" => "same" }) do |dir|
      File.write(File.join(dir, "unmanaged.svg"), "local")
      f = fetcher(icon_url("a", tag: "1.0.0") => "same")

      SYNC.new(dir, fetcher: f).sync(tag: "1.0.0")

      manifest = MANIFEST.read(dir)

      assert_equal %w[a], manifest.icons.keys
      assert_equal({ "added" => %w[unmanaged] }, manifest.drift(dir))
    end
  end

  def test_sync_fetches_through_alias
    with_pack(icons: { "old" => "stale" },
              manifest_icons: { aliases: { "old" => "new-name" } }) do |dir|
      f = release_fetcher(icon_url("new-name") => "fresh-bytes")
      result = SYNC.new(dir, fetcher: f).sync

      assert_equal "fresh-bytes", File.read(File.join(dir, "old.svg"))
      assert_equal %w[old], result["updated"]
    end
  end

  def test_sync_propagates_non_404_errors
    with_pack(icons: { "a" => "x" }) do |dir|
      f = release_fetcher(icon_url("a") => Jekyll::IconFlow::Error.new("HTTP 500 fetching x"))
      assert_raises(Jekyll::IconFlow::Error) { SYNC.new(dir, fetcher: f).sync }
    end
  end

  def test_sync_rejects_unsafe_local_name_even_with_injected_manifest
    with_pack(icons: { "a" => "x" }) do |dir|
      manifest = MANIFEST.new(
        "pack" => "test", "upstream_repo" => REPO,
        "upstream_url" => "https://example.test", "license" => "MIT",
        "version" => "1.0.0", "vendored" => "2026-01-01",
        "aliases" => { "../outside" => "a" },
        "icons" => { "../outside" => "0" * 64 }
      )
      f = fetcher(icon_url("a", tag: "1.0.0") => "fresh")

      assert_raises(Jekyll::IconFlow::Error) do
        SYNC.new(dir, manifest: manifest, fetcher: f).sync(tag: "1.0.0")
      end
    end
  end

  # --- PackTasks (rake runners) ----------------------------------------
  # report_all/sync_all take a ROOT containing pack subdirectories.

  TASKS = Jekyll::IconFlow::PackTasks

  def with_root(icons)
    Dir.mktmpdir do |root|
      Dir.mkdir(File.join(root, "test"))
      write_pack(File.join(root, "test"), icons)
      yield root
    end
  end

  def test_report_all_prints_table_and_returns_true_when_current
    with_root("a" => "x") do |root|
      f = release_fetcher("#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"1.0.0"}')
      result = nil
      out, = capture_io { result = TASKS.report_all?(root, fetcher: f) }

      assert result
      assert_match(/test +1\.0\.0 -> 1\.0\.0 +current/, out)
      assert_match(/All vendored icon packs are current/, out)
    end
  end

  def test_report_all_marks_behind_pack_and_returns_false
    with_root("a" => "x") do |root|
      result = nil
      out, = capture_io { result = TASKS.report_all?(root, fetcher: release_fetcher) }

      refute result
      assert_match(/test +1\.0\.0 -> 2\.0\.0 +BEHIND/, out)
      assert_match(/1 pack\(s\) need attention: test/, out)
    end
  end

  def test_report_all_prints_drift_lines
    with_root("a" => "x") do |root|
      File.write(File.join(root, "test", "a.svg"), "tampered")
      result = nil
      f = release_fetcher("#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"1.0.0"}')
      out, = capture_io { result = TASKS.report_all?(root, fetcher: f) }

      refute result
      assert_match(/drift: modified a/, out)
      assert_match(/ISSUES/, out)
    end
  end

  def test_report_all_fails_when_upstream_icons_are_unresolved
    with_root("a" => "x") do |root|
      manifest_path = File.join(root, "test", "PACK.yml")
      manifest = MANIFEST.read(File.dirname(manifest_path))
      manifest.missing_upstream = ["a"]
      manifest.write(File.dirname(manifest_path))
      f = release_fetcher("#{SYNC::API}/repos/#{REPO}/releases/latest" => '{"tag_name":"1.0.0"}')
      result = nil
      out, = capture_io { result = TASKS.report_all?(root, fetcher: f) }

      refute result
      assert_match(/missing upstream: a/, out)
    end
  end

  def test_sync_all_aborts_on_unknown_pack
    with_root("a" => "x") do |root|
      assert_raises(SystemExit) { TASKS.sync_all(root, pack: "nope", fetcher: release_fetcher) }
    end
  end

  def test_sync_all_prints_result_and_missing_icons
    with_root("a" => "old", "gone" => "local") do |root|
      f = release_fetcher(icon_url("a") => "new",
                          icon_url("gone") => Jekyll::IconFlow::Error.new("HTTP 404 x"))
      out, = capture_io { TASKS.sync_all(root, fetcher: f) }

      assert_match(/test +-> 2\.0\.0 \(2 icons, 1 updated\)/, out)
      assert_match(/missing upstream: gone/, out)
    end
  end

  # --- http_get (network boundary) -------------------------------------

  def http_response(klass, code, body: nil, location: nil)
    response = klass.new("1.1", code, "msg")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    response["location"] = location if location
    response
  end

  def test_http_get_returns_body
    responses = ->(_req) { http_response(Net::HTTPOK, 200, body: "BYTES") }

    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responses)) }) do
      assert_equal "BYTES", Jekyll::IconFlow::HttpFetch.get("https://example.test/x")
    end
  end

  def http_stub(responder)
    http = Object.new
    http.define_singleton_method(:request) { |req| responder.call(req) }
    http
  end

  def test_http_get_raises_on_http_error
    Net::HTTP.stub(:start, lambda { |*, **, &b|
      b.call(http_stub(lambda { |_r|
        http_response(Net::HTTPNotFound, 404)
      }))
    }) do
      error = assert_raises(Jekyll::IconFlow::Error) { Jekyll::IconFlow::HttpFetch.get("https://example.test/x") }
      assert_match(/HTTP 404/, error.message)
    end
  end

  def test_http_get_follows_redirects
    hops = 0
    responder = lambda do |_req|
      hops += 1
      if hops == 1
        http_response(Net::HTTPFound, 302, location: "https://cdn.test/final")
      else
        http_response(Net::HTTPOK, 200, body: "done")
      end
    end
    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responder)) }) do
      assert_equal "done", Jekyll::IconFlow::HttpFetch.get("https://example.test/x")
      assert_equal 2, hops
    end
  end

  def test_http_get_resolves_relative_redirects
    requested = []
    responder = lambda do |req|
      requested << req.path
      if requested.size == 1
        http_response(Net::HTTPFound, 302, location: "/final")
      else
        http_response(Net::HTTPOK, 200, body: "done")
      end
    end
    body = nil
    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responder)) }) do
      body = Jekyll::IconFlow::HttpFetch.get("https://example.test/start")
    end

    assert_equal "done", body
    assert_equal ["/start", "/final"], requested
  end

  def test_http_get_rejects_plain_http
    assert_raises(Jekyll::IconFlow::Error) do
      Jekyll::IconFlow::HttpFetch.get("http://example.test/x")
    end
  end

  def test_http_get_fails_on_redirect_loop
    responder = ->(_req) { http_response(Net::HTTPFound, 302, location: "https://example.test/loop") }
    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responder)) }) do
      error = assert_raises(Jekyll::IconFlow::Error) { Jekyll::IconFlow::HttpFetch.get("https://example.test/x") }
      assert_match(/too many redirects/, error.message)
    end
  end

  def test_http_get_fails_on_locationless_redirect
    responder = ->(_req) { http_response(Net::HTTPFound, 302) }

    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responder)) }) do
      assert_raises(Jekyll::IconFlow::Error) { Jekyll::IconFlow::HttpFetch.get("https://example.test/x") }
    end
  end

  def test_http_get_sends_token_only_to_github_api
    requests = []
    responder = lambda do |req|
      requests << req
      http_response(Net::HTTPOK, 200, body: "{}")
    end
    Net::HTTP.stub(:start, ->(*, **, &b) { b.call(http_stub(responder)) }) do
      with_env("GITHUB_TOKEN" => "secret") do
        Jekyll::IconFlow::HttpFetch.get("https://api.github.com/repos/a/b/releases/latest")
        Jekyll::IconFlow::HttpFetch.get("https://raw.githubusercontent.com/a/b/tag/icons/x.svg")
      end
    end

    assert_equal "Bearer secret", requests[0]["Authorization"]
    assert_nil requests[1]["Authorization"]
  end

  def with_env(vars)
    old = vars.to_h { |k, _v| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
