# Changelog

## [Unreleased]

### Fixed

- CI: pinned-Jekyll matrix legs failed at `bundle install` — setup-ruby's
  `bundler-cache` installs frozen, but a leg's `JEKYLL_VERSION`-gated Gemfile
  never matches the committed lockfile. `bundler-cache` now runs only on the
  `latest` leg; pinned legs install unfrozen.

## [0.1.2] - 2026-10-30

### Changed

- CI: Semgrep bumped 1.176.0 → 1.182.0 — the standalone job runs the
  digest-pinned `semgrep/semgrep:1.182.0` container image; matrix/release
  jobs install it via `pipx install semgrep==1.182.0`. Added
  `.github/dependabot.yml` covering github-actions and bundler updates.
- Tests migrated from RSpec to Minitest (`spec/` → `test/`; `minitest` +
  `minitest-mock` for `Object#stub`, `jekyll-test-harness` via
  `install!(framework: :minitest)`). The vendored-icon smoke test is now
  generated per icon so a corrupt SVG names the icon in the failure;
  SimpleCov tracks branch coverage.
- CI matrixes Jekyll minors (`~> 4.0.0`, `~> 4.2.0`, latest) × Ruby
  3.3/3.4 via a `JEKYLL_VERSION`-gated Gemfile pin; pinned legs run
  `rake test` only because RuboCop's `unicode-display_width` can't
  resolve with pre-4.3 `terminal-table`. `csv`/`base64`/`bigdecimal` are
  declared for old Jekyll on Ruby 3.4.
- Added `test/system/gem_artifact_test.rb` — builds the packaged `.gem`
  and runs a real `jekyll build` against it (`rake test:system`, part of
  `rake ci`).

## [0.1.1] - 2026-10-06

### Fixed

- `LICENSE.txt` now contains the verbatim AGPL-3.0 text (was a stub
  that license scanners could not detect); copyright attribution moved
  to the README license section.

### Added

- Per-pack smoke spec rendering every vendored icon — a corrupt bundled
  SVG now fails the suite instead of the first page that uses it.
- `Jekyll::IconFlow::Interface.to_h` — the public tag/param/config/enum
  surface (including adapter-bound `icon_<pack>` tags and the vendored
  icon listing) derived from `ADAPTERS`/`SIZES`, serialized to a
  committed `interface.yml` by `rake interface`.
- `spec/interface_spec.rb` pins code ↔ manifest ↔ docs and vendored-SVG
  ↔ manifest parity for the VS Code extension.

## [0.1.0] - 2026-10-04

- `{% icon %}` + per-pack `{% icon_<pack> %}` Liquid tags (lucide,
  simple-icons, custom dir) with fleet-convention aliases
  (`{% lucide_icon %}` etc.)
- `{% icon_ref <key> %}` — semantic names resolved through
  `icon_flow.registry` (`pack:name[:class]` entries)
- Normalized output contract: `icon icon-<name>` classes, `currentColor`,
  `data-icon-pack` hook, inline em-based sizing with a named scale
  (`xxs`–`xxl`, default `m` = 1em line-height) or a literal CSS size
- `{% icon %}` searches packs in order (default custom → simple → lucide)
  instead of a single default pack; `pack:`/`icon_flow.pack` pin to one pack
- `icon_flow.packs` — named extra packs from site directories of `.svg`
  files (fontawesome, tabler, …), usable via `pack:`, the search chain,
  and `icon_ref` registry targets
- `icon_flow.on_missing: warn|strict` — warn + empty render by default
- Escape Liquid-supplied SVG attributes, validate icon sizes, and
  normalize child SVG colors.
- RSpec integration/adapter contracts, coverage reporting, Semgrep and
  gem-artifact checks.
