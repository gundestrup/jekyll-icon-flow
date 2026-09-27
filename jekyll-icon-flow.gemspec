# frozen_string_literal: true

require_relative "lib/jekyll/icon_flow/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-icon-flow"
  spec.version = Jekyll::IconFlow::VERSION
  spec.authors = ["Svend Gundestrup"]
  spec.email = ["svend@gundestrup.dk"]
  spec.summary = "Pack-agnostic inline SVG icon tags for Jekyll"
  spec.description = "A Jekyll plugin providing {% icon %} and per-pack {% icon_<pack> %} " \
                     "Liquid tags. Each icon pack is an adapter that resolves names to SVG " \
                     "sources and normalizes output — same styling contract across packs."
  spec.homepage = "https://github.com/gundestrup/jekyll-icon-flow"
  spec.license = "AGPL-3.0-or-later"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/gundestrup/jekyll-icon-flow/tree/main",
    "changelog_uri" => "https://github.com/gundestrup/jekyll-icon-flow/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/gundestrup/jekyll-icon-flow/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.3.0"
  spec.files = Dir["lib/**/*", "assets/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 4.0", "< 5.0"
end
