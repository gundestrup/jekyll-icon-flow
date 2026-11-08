# Changelog

## [Unreleased]

## [0.2.0] - 2026-11-08

### Added

- Icon-pack freshness tooling: each vendored pack now carries a
  `PACK.yml` provenance manifest (upstream repo, license, release tag,
  vendored date, per-icon SHA-256 digests, `aliases` for upstream
  renames, and persistent `missing_upstream` entries). `rake icons:check`
  reports stale releases, local drift, and unresolved icons
  (`STRICT=1` fails); `rake icons:sync[pack]` re-downloads the manifest's
  curated icon list without blessing unrelated local files.
- `version:pre_release` runs `icons:check` in strict mode so stale,
  drifted, or unresolved packs block a release.
- `.github/workflows/icons-sync.yml` — weekly scheduled sync that opens
  a PR when upstream icon packs released new versions.
- `rake docs:demo` — generates `docs/assets/` showcase page from real
  adapter output and captures it as animated AVIF + WebP + static PNG
  (headless Chrome + ffmpeg libsvtav1 + img2webp; build-host tools),
  embedded in README via `<picture>`.

### Changed

- Restored Lucide's legacy `lucide lucide-<name>` CSS classes in rendered
  SVG while keeping vendored files byte-identical to upstream.
- Dependency updates: `addressable` 2.9.1 → 2.9.2, `minitest`
  6.0.6 → 6.1.0, `sass-embedded` 1.107.0 → 1.108.1; pinned-leg
  lockfiles refreshed (`minitest` 6.1.0, `prism` 1.9.0 → 2.1.0).
- CI: `ruby/setup-ruby` pin bumped v1.335.0 → v1.338.0;
  `BUNDLED WITH` bumped 4.0.21 → 4.0.24.

### Fixed

- CI: pinned-Jekyll matrix legs failed at `bundle install` — the
  `JEKYLL_VERSION`-gated Gemfile never matched the committed lockfile under
  frozen install. Legs now use `BUNDLE_GEMFILE` with committed
  `gemfiles/*.gemfile.lock`, so every leg installs frozen and cacheable;
  dependabot covers `/gemfiles`.

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
