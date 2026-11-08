# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "error"
require_relative "pack_manifest"

module Jekyll
  module IconFlow
    # Minimal HTTPS fetch for the icon-sync tooling: GET => body,
    # following redirects. GITHUB_TOKEN is sent to the GitHub API only
    # (rate-limit headroom in CI), never to raw hosts.
    module HttpFetch
      API_HOST = "api.github.com"
      MAX_REDIRECTS = 3

      module_function

      def get(url, redirects: 0)
        uri = URI(url)
        raise Error, "only HTTPS URLs are allowed: #{url}" unless uri.is_a?(URI::HTTPS)

        response = request(uri)
        case response
        when Net::HTTPSuccess then response.body
        when Net::HTTPRedirection then follow(response, url, redirects)
        else
          raise Error, "HTTP #{response.code} fetching #{url}"
        end
      end

      def follow(response, url, redirects)
        raise Error, "too many redirects fetching #{url}" if redirects >= MAX_REDIRECTS
        raise Error, "redirect without location fetching #{url}" unless response["location"]

        get(URI.join(url, response["location"]).to_s, redirects: redirects + 1)
      rescue URI::InvalidURIError => e
        raise Error, "invalid redirect fetching #{url}: #{e.message}"
      end

      def request(uri)
        request = Net::HTTP::Get.new(uri)
        if uri.host == API_HOST && uri.port == 443 && ENV["GITHUB_TOKEN"]
          request["Authorization"] = "Bearer #{ENV['GITHUB_TOKEN']}"
        end
        Net::HTTP.start(uri.host, uri.port,
                        use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
          http.request(request)
        end
      end
    end

    # URL construction and release metadata validation are shared by the
    # check and sync operations.
    module PackUpstream
      API = "https://api.github.com"
      RAW = "https://raw.githubusercontent.com"
      ICONS_SUBDIR = "icons"

      module_function

      def latest_version(repo, fetcher:)
        raise Error, "invalid upstream repository name: #{repo.inspect}" unless
          PackManifest.valid_repository?(repo)

        data = JSON.parse(fetcher.call("#{API}/repos/#{repo}/releases/latest"))
        release_tag(repo, data)
      rescue JSON::ParserError => e
        raise Error, "unparseable release response for #{repo}: #{e.message}"
      end

      def release_tag(repo, data)
        unless data.is_a?(Hash)
          raise Error, "invalid release response for #{repo}: expected an object"
        end

        tag = data["tag_name"]
        raise Error, "no tag_name in latest release for #{repo}" if tag.to_s.empty?
        raise Error, "invalid release tag for #{repo}: #{tag.inspect}" unless
          PackManifest.valid_release_tag?(tag)

        tag
      end

      def raw_icon_url(repo, tag, icon_name)
        unless PackManifest.valid_repository?(repo) &&
               PackManifest.valid_release_tag?(tag) &&
               PackManifest.valid_icon_name?(icon_name)
          raise Error, "invalid upstream icon URL components"
        end

        "#{RAW}/#{repo}/#{tag}/#{ICONS_SUBDIR}/#{icon_name}.svg"
      end
    end

    # Freshness tooling for vendored icon packs (PACK.yml manifests).
    # `check` reports each pack's vendored upstream tag vs the latest
    # GitHub release; `sync` re-downloads the manifest's icon list from
    # the upstream repo at a release tag and rewrites PACK.yml.
    #
    # Network access is injected via `fetcher` (url => body) so the logic
    # is unit-testable; production tasks use HttpFetch.get.
    class PackSync
      API = PackUpstream::API
      RAW = PackUpstream::RAW
      ICONS_SUBDIR = PackUpstream::ICONS_SUBDIR

      attr_reader :dir, :manifest

      # Every managed pack dir under root (one containing PACK.yml).
      def self.each(root, fetcher: nil)
        Dir.children(root).sort.filter_map do |name|
          dir = File.join(root, name)
          next unless File.directory?(dir)

          manifest = PackManifest.read(dir)
          manifest ? new(dir, manifest: manifest, fetcher: fetcher) : nil
        end
      end

      def initialize(dir, manifest: nil, fetcher: nil)
        @dir = dir
        @fetcher = fetcher || ->(url) { HttpFetch.get(url) }
        @manifest = manifest || PackManifest.read(dir)
      end

      # Latest release tag for the manifest's upstream repo.
      def latest_version
        self.class.latest_version(manifest.upstream_repo, fetcher: @fetcher)
      end

      def self.latest_version(repo, fetcher:)
        PackUpstream.latest_version(repo, fetcher: fetcher)
      end

      def self.raw_icon_url(repo, tag, icon_name)
        PackUpstream.raw_icon_url(repo, tag, icon_name)
      end

      # Behind upstream when the latest release tag sorts higher than the
      # vendored one. For non-semver tags, a different tag is treated as newer.
      def behind?(latest = latest_version)
        return false if latest == manifest.version

        Gem::Version.new(latest) > Gem::Version.new(manifest.version)
      rescue ArgumentError
        latest != manifest.version
      end

      # Freshness report — pure data, the rake task owns presentation.
      def check
        latest = latest_version
        {
          "pack" => manifest.pack, "current" => manifest.version,
          "latest" => latest, "behind" => behind?(latest),
          "drift" => manifest.drift(dir), "missing_upstream" => manifest.missing_upstream
        }
      end

      # Re-vendor every icon in the manifest from upstream at `tag`
      # (default: latest release). Only fetches files whose bytes differ;
      # icons missing upstream are kept locally and reported so a rename
      # remains visible in PACK.yml until a maintainer resolves it.
      def sync(tag: nil)
        tag ||= latest_version
        previous = manifest_snapshot
        changed, missing = refresh_icons(tag)
        changed.sort!
        missing.sort!
        manifest.capture_icons!(dir, preserve_missing: missing)
        manifest.missing_upstream = missing
        record_sync!(tag) if sync_changed?(tag, previous, changed)
        sync_result(tag, changed, missing)
      end

      private

      def manifest_snapshot
        [manifest.version, manifest.icons.dup, manifest.missing_upstream.dup]
      end

      def sync_changed?(tag, previous, changed)
        tag != previous[0] || !changed.empty? ||
          manifest.icons != previous[1] || manifest.missing_upstream != previous[2]
      end

      def record_sync!(tag)
        manifest.version = tag
        manifest.vendored = Time.now.utc.strftime("%Y-%m-%d")
        manifest.write(dir)
      end

      def sync_result(tag, changed, missing)
        { "pack" => manifest.pack, "version" => tag, "updated" => changed,
          "missing_upstream" => missing, "icons" => manifest.icons.size }
      end

      def refresh_icons(tag)
        manifest.icons.each_key.with_object([[], []]) do |name, (changed, missing)|
          svg = fetch_icon(manifest.upstream_repo, tag, manifest.upstream_name(name))
          if svg.nil?
            missing << name
          elsif write_icon?(name, svg)
            changed << name
          end
        end
      end

      def fetch_icon(repo, tag, name)
        @fetcher.call(self.class.raw_icon_url(repo, tag, name))
      rescue Error => e
        return nil if e.message.start_with?("HTTP 404")

        raise
      end

      def write_icon?(name, svg)
        raise Error, "invalid icon name: #{name.inspect}" unless PackManifest.valid_icon_name?(name)

        root = File.expand_path(dir)
        path = File.expand_path("#{name}.svg", root)
        raise Error, "icon path escapes pack directory: #{name.inspect}" unless
          path.start_with?("#{root}#{File::SEPARATOR}")
        raise Error, "refusing to write through icon symlink: #{path}" if File.symlink?(path)

        return false if File.file?(path) && File.binread(path) == svg

        File.write(path, svg, mode: "wb")
        true
      end
    end

    # Command runners behind `rake icons:check` / `rake icons:sync` —
    # pack-level logic lives in PackSync; this module owns iteration and
    # console output so the Rakefile tasks stay one-liners.
    module PackTasks
      module_function

      # Prints the freshness table; returns true when all packs are current.
      def report_all?(root, fetcher: nil)
        reports = PackSync.each(root, fetcher: fetcher).map(&:check)
        reports.each { |report| print_check(report) }
        issues = reports.reject { |report| current?(report) }
        print_check_summary(issues)
        issues.empty?
      end

      def print_check(report)
        marker = status_marker(report)
        puts format("%-10<pack>s %<current>s -> %<latest>s  %<marker>s",
                    pack: report["pack"], current: report["current"],
                    latest: report["latest"], marker: marker)
        print_drift(report)
        print_missing_upstream(report)
      end

      def current?(report)
        !report["behind"] && report["drift"].empty? && report["missing_upstream"].empty?
      end

      def status_marker(report)
        return "BEHIND" if report["behind"]
        return "current" if current?(report)

        "ISSUES"
      end

      def print_drift(report)
        report["drift"].each do |kind, names|
          puts "           drift: #{kind} #{names.join(', ')}"
        end
      end

      def print_missing_upstream(report)
        missing = report["missing_upstream"]
        return if missing.empty?

        puts "           missing upstream: #{missing.join(', ')}"
      end

      def print_check_summary(issues)
        if issues.empty?
          puts "All vendored icon packs are current with no local drift."
        else
          packs = issues.map { |report| report["pack"] }
          summary = "#{issues.size} pack(s) need attention: #{packs.join(', ')}"
          puts "#{summary} — run `rake icons:sync`"
        end
      end

      def sync_all(root, pack: nil, fetcher: nil)
        packs = PackSync.each(root, fetcher: fetcher)
        packs = packs.select { |p| p.manifest.pack == pack } if pack
        if packs.empty?
          abort "Unknown pack '#{pack}' (managed packs have assets/icons/<pack>/PACK.yml)"
        end

        packs.each { |p| print_sync(p.sync) }
      end

      def print_sync(result)
        puts format("%-10<pack>s -> %<version>s (%<icons>d icons, %<updated>d updated)",
                    pack: result["pack"], version: result["version"],
                    icons: result["icons"], updated: result["updated"].size)
        missing = result["missing_upstream"]
        return if missing.empty?

        puts "           kept locally, missing upstream: #{missing.join(', ')}"
      end
    end
  end
end
