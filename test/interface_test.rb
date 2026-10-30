# frozen_string_literal: true

require "test_helper"
require "yaml"

class InterfaceManifestTest < IconFlowTest
  ROOT = File.expand_path("..", __dir__)
  INTERFACE = Jekyll::IconFlow::Interface.to_h

  def test_matches_the_committed_interface_yml
    manifest = YAML.load_file(File.join(ROOT, "interface.yml"))

    assert_equal INTERFACE, manifest
  end

  def test_has_every_declared_tag_registered_with_liquid
    registered = Liquid::Template.tags.map(&:first)

    assert_empty(INTERFACE["tags"].keys - registered)
  end

  def test_lists_exactly_the_param_keys_the_tags_and_adapters_read
    sources = %w[icon_tag.rb icon_ref_tag.rb adapter.rb].map do |file|
      File.read(File.join(ROOT, "lib/jekyll/icon_flow", file))
    end.join("\n")
    pattern = /(?:params|options)\s*(?:\[\s*["'](\w+)["']\s*\]|\.delete\(\s*["'](\w+)["']\s*\))/
    used = []
    pos = 0
    while (match = pattern.match(sources, pos))
      used << match.captures.compact.first
      pos = match.end(0)
    end

    assert_equal %w[class pack size title], used.uniq.sort
  end

  def test_declares_exactly_the_config_keys_read_via_dig
    sources = Dir[File.join(ROOT, "lib/**/*.rb")].map { |f| File.read(f) }.join("\n")
    dig_pattern = /dig\("icon_flow",\s*"(\w+)"/
    read = []
    pos = 0
    while (match = dig_pattern.match(sources, pos))
      read << match[1]
      pos = match.end(0)
    end
    read = read.uniq.sort

    assert_equal read, INTERFACE.dig("config", "icon_flow")
  end

  def test_documents_every_tag_param_config_key_and_enum_value
    docs = (Dir[File.join(ROOT, "*.md")] +
            Dir[File.join(ROOT, "docs/**/*.md")])
           .map { |f| File.read(f) }.join("\n")

    missing = []
    INTERFACE["tags"].each do |tag, spec|
      missing << "tag `#{tag}`" unless docs.match?(/\b#{tag}\b/)
      spec["params"].each do |param|
        missing << "#{tag} param `#{param}:`" unless docs.match?(/\b#{param}\s*:/)
      end
    end
    INTERFACE["config"].each do |section, keys|
      keys.each do |key|
        missing << "#{section} config `#{key}`" unless docs.match?(/\b#{key}\b/)
      end
    end
    INTERFACE["enums"].each do |setting, values|
      values.each do |value|
        missing << "#{setting} value `#{value}`" unless docs.match?(/\b#{Regexp.escape(value)}\b/)
      end
    end

    assert_empty missing, "interface items missing from docs:\n  #{missing.join("\n  ")}"
  end
end
