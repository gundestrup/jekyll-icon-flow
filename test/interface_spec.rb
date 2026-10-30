# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "interface manifest" do
  root = File.expand_path("..", __dir__)
  interface = Jekyll::IconFlow::Interface.to_h

  it "matches the committed interface.yml" do
    manifest = YAML.load_file(File.join(root, "interface.yml"))
    expect(manifest).to eq(interface)
  end

  it "has every declared tag registered with Liquid" do
    registered = Liquid::Template.tags.map(&:first)
    expect(interface["tags"].keys - registered).to be_empty
  end

  it "lists exactly the param keys the tags and adapters read" do
    sources = %w[icon_tag.rb icon_ref_tag.rb adapter.rb].map do |file|
      File.read(File.join(root, "lib/jekyll/icon_flow", file))
    end.join("\n")
    pattern = /(?:params|options)\s*(?:\[\s*["'](\w+)["']\s*\]|\.delete\(\s*["'](\w+)["']\s*\))/
    used = []
    pos = 0
    while (match = pattern.match(sources, pos))
      used << match.captures.compact.first
      pos = match.end(0)
    end
    expect(used.uniq.sort).to eq(%w[class pack size title])
  end

  it "declares exactly the config keys read via dig" do
    sources = Dir[File.join(root, "lib/**/*.rb")].map { |f| File.read(f) }.join("\n")
    dig_pattern = /dig\("icon_flow",\s*"(\w+)"/
    read = []
    pos = 0
    while (match = dig_pattern.match(sources, pos))
      read << match[1]
      pos = match.end(0)
    end
    read = read.uniq.sort
    expect(interface.dig("config", "icon_flow")).to eq(read)
  end

  it "documents every tag, param, config key, and enum value" do
    docs = (Dir[File.join(root, "*.md")] +
            Dir[File.join(root, "docs/**/*.md")])
           .map { |f| File.read(f) }.join("\n")

    missing = []
    interface["tags"].each do |tag, spec|
      missing << "tag `#{tag}`" unless docs.match?(/\b#{tag}\b/)
      spec["params"].each do |param|
        missing << "#{tag} param `#{param}:`" unless docs.match?(/\b#{param}\s*:/)
      end
    end
    interface["config"].each do |section, keys|
      keys.each do |key|
        missing << "#{section} config `#{key}`" unless docs.match?(/\b#{key}\b/)
      end
    end
    interface["enums"].each do |setting, values|
      values.each do |value|
        missing << "#{setting} value `#{value}`" unless docs.match?(/\b#{Regexp.escape(value)}\b/)
      end
    end

    expect(missing).to be_empty,
                       "interface items missing from docs:\n  #{missing.join("\n  ")}"
  end
end
