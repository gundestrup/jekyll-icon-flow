# frozen_string_literal: true

require_relative "lib/jekyll/icon_flow/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-icon-flow"
  spec.version = Jekyll::IconFlow::VERSION
  spec.authors = ["Svend Gundestrup"]
  spec.email = ["svend@gundestrup.dk"]
  spec.summary = "Pack-agnostic inline SVG icon tags for Jekyll"
  # NOTE: rubygems.org renders the description through RDoc::Markup only
  # when it starts with an == heading at column 0 — keep the heredoc
  # content flush-left or the page renders as one plain <p>.
  spec.description = <<~DESC
    == Pack-agnostic inline SVG icons for Jekyll

    Provides per-pack icon tags (icon_lucide, icon_simple, icon_custom) and
    icon_ref registry lookups. Each pack adapter resolves names to SVG
    sources with the same styling contract: size:, class:, title:.

    * Bundled lucide + simple-icons packs, plus custom_dir packs
    * Named em-relative sizes that scale with surrounding text
    * icon_ref: name intent once in the registry, swap packs globally

    A companion VS Code extension (jekyll-imgflow-vscode) provides tag
    autocomplete: https://github.com/gundestrup/jekyll-imgflow-vscode
  DESC
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
  spec.files = Dir["lib/**/*", "assets/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md",
                   "interface.yml"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 4.0", "< 5.0"
end
