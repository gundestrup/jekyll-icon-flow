# frozen_string_literal: true

require "yaml"
require "digest"

module Jekyll
  module IconFlow
    # Provenance manifest for a vendored icon pack, stored as PACK.yml
    # inside the pack directory (assets/icons/<pack>/PACK.yml). Records
    # which upstream release the SVGs were vendored from plus a per-icon
    # digest, so `rake icons:check` can report staleness and detect local
    # drift without touching the network.
    #
    #   pack: lucide
    #   upstream_repo: lucide-icons/lucide
    #   upstream_url: https://lucide.dev
    #   license: ISC
    #   version: "1.70.0"        # upstream release tag
    #   vendored: "2026-11-08"   # date the files were synced
    #   icons:
    #     search: <sha256 of file bytes>
    module PackManifestSchema
      REQUIRED_KEYS = %w[pack upstream_repo upstream_url license version vendored].freeze
      ICON_NAME = /\A[a-z0-9_-]+\z/
      SHA256 = /\A[0-9a-f]{64}\z/
      GITHUB_REPOSITORY = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}
      RELEASE_TAG = /\A[A-Za-z0-9][A-Za-z0-9._+-]*\z/

      module_function

      def valid_icon_name?(name)
        name.is_a?(String) && name.match?(ICON_NAME)
      end

      def valid_repository?(repo)
        return false unless repo.is_a?(String) && repo.match?(GITHUB_REPOSITORY)

        !repo.split("/").intersect?(%w[. ..])
      end

      def valid_release_tag?(tag)
        tag.is_a?(String) && tag.match?(RELEASE_TAG)
      end

      def validate!(manifest)
        validate_required_keys!(manifest)
        validate_required_values!(manifest)
        validate_icon_digests!(manifest)
        validate_aliases!(manifest)
        validate_missing_upstream!(manifest)
        validate_icon_references!(manifest)
      end

      def validate_required_keys!(manifest)
        missing = REQUIRED_KEYS.select { |key| manifest.public_send(key).nil? }
        return if missing.empty?

        raise Error, "PACK.yml missing keys: #{missing.join(', ')}"
      end

      def validate_required_values!(manifest)
        validate_required_strings!(manifest)
        validate_repository_values!(manifest)
      end

      def validate_required_strings!(manifest)
        invalid = REQUIRED_KEYS.reject do |key|
          value = manifest.public_send(key)
          value.is_a?(String) && !value.empty?
        end
        raise Error, "PACK.yml required values must be non-empty strings" unless invalid.empty?
      end

      def validate_repository_values!(manifest)
        raise Error, "PACK.yml has an invalid pack name" unless valid_icon_name?(manifest.pack)
        unless valid_repository?(manifest.upstream_repo)
          raise Error, "PACK.yml has an invalid upstream repository"
        end
        return if valid_release_tag?(manifest.version)

        raise Error, "PACK.yml has an invalid release tag"
      end

      def validate_icon_digests!(manifest)
        raise Error, "PACK.yml icons must be a name => sha256 map" unless manifest.icons.is_a?(Hash)

        invalid = manifest.icons.find do |name, digest|
          !valid_icon_name?(name) || !digest.is_a?(String) || !digest.match?(SHA256)
        end
        raise Error, "PACK.yml icons contain an invalid name or SHA-256 digest" if invalid
      end

      def validate_aliases!(manifest)
        unless manifest.aliases.is_a?(Hash)
          raise Error, "PACK.yml aliases must be a name => upstream_name map"
        end

        invalid = manifest.aliases.find do |name, upstream_name|
          !valid_icon_name?(name) || !valid_icon_name?(upstream_name)
        end
        raise Error, "PACK.yml aliases contain an invalid icon name" if invalid
      end

      def validate_missing_upstream!(manifest)
        unless manifest.missing_upstream.is_a?(Array)
          raise Error, "PACK.yml missing_upstream must be an array of icon names"
        end

        invalid = manifest.missing_upstream.find { |name| !valid_icon_name?(name) }
        raise Error, "PACK.yml missing_upstream contains an invalid icon name" if invalid
      end

      def validate_icon_references!(manifest)
        unless (manifest.aliases.keys - manifest.icons.keys).empty?
          raise Error, "PACK.yml aliases must reference names in icons"
        end
        return if (manifest.missing_upstream - manifest.icons.keys).empty?

        raise Error, "PACK.yml missing_upstream must reference names in icons"
      end
    end

    class PackManifest
      FILENAME = "PACK.yml"
      KEYS = %w[
        pack upstream_repo upstream_url license version vendored aliases icons missing_upstream
      ].freeze

      attr_reader :pack, :upstream_repo, :upstream_url, :license, :icons
      attr_accessor :version, :vendored, :aliases, :missing_upstream

      def self.path_for(dir)
        File.join(dir, FILENAME)
      end

      # Manifest for the pack in dir, or nil when the pack has none
      # (unmanaged packs — e.g. site-provided custom dirs — are skipped).
      def self.read(dir)
        path = path_for(dir)
        return nil unless File.file?(path)

        data = YAML.safe_load_file(path)
        raise Error, "invalid #{path}: expected a mapping" unless data.is_a?(Hash)

        manifest = new(data.transform_keys(&:to_s))
        manifest.validate!
        manifest
      rescue Psych::Exception => e
        raise Error, "invalid #{path}: #{e.message}"
      end

      def initialize(fields = {})
        fields.each { |key, value| instance_variable_set("@#{key}", value) }
        @icons ||= {}
        @aliases ||= {}
        @missing_upstream ||= []
      end

      def validate!
        PackManifestSchema.validate!(self)
        self
      end

      def self.valid_icon_name?(name)
        PackManifestSchema.valid_icon_name?(name)
      end

      def self.valid_repository?(repo)
        PackManifestSchema.valid_repository?(repo)
      end

      def self.valid_release_tag?(tag)
        PackManifestSchema.valid_release_tag?(tag)
      end

      # Upstream filename base for a vendored icon — follows the rename
      # chain recorded in aliases (local name => upstream name).
      def upstream_name(icon_name)
        aliases.fetch(icon_name, icon_name)
      end

      def to_h
        KEYS.to_h { |key| [key, public_send(key)] }
            .reject { |key, value| %w[aliases missing_upstream].include?(key) && value.empty? }
      end

      def write(dir)
        File.write(self.class.path_for(dir),
                   "# Vendored pack provenance — maintained by `rake icons:sync`.\n" \
                   "# Edit icons only via that task so this file stays truthful.\n" +
                   to_h.to_yaml)
      end

      def self.file_sha256(path)
        Digest::SHA256.file(path).hexdigest
      end

      # name => sha256 for every .svg in dir — the manifest's icons map.
      def self.icon_digests(dir)
        Dir.children(dir).grep(/\.svg\z/).sort.to_h do |file|
          [file.delete_suffix(".svg"), file_sha256(File.join(dir, file))]
        end
      end

      # Refresh only the manifest's curated names; never bless local additions.
      # Missing upstream icons retain their last digest until a maintainer acts.
      def capture_icons!(dir, preserve_missing: [])
        actual = self.class.icon_digests(dir)
        @icons = icons.each_with_object({}) do |(name, old_digest), digests|
          if preserve_missing.include?(name)
            digests[name] = old_digest
          elsif actual.key?(name)
            digests[name] = actual[name]
          end
        end
        self
      end

      # Local edits vs the manifest: icons added/removed by hand, or SVG
      # bytes changed since the last sync. Empty hash means clean.
      def drift(dir)
        actual = self.class.icon_digests(dir)
        {
          "added" => (actual.keys - icons.keys).sort,
          "removed" => (icons.keys - actual.keys).sort,
          "modified" => modified_icons(actual)
        }.reject { |_key, names| names.empty? }
      end

      private

      def modified_icons(actual)
        (icons.keys & actual.keys).reject { |name| icons[name] == actual[name] }.sort
      end
    end
  end
end
