# jekyll-icon-flow

[![Status: Active](https://img.shields.io/badge/status-active-success)](https://github.com/gundestrup/jekyll-icon-flow)
[![CI](https://github.com/gundestrup/jekyll-icon-flow/actions/workflows/ci.yml/badge.svg)](https://github.com/gundestrup/jekyll-icon-flow/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/jekyll-icon-flow)](https://rubygems.org/gems/jekyll-icon-flow)
[![Codecov](https://codecov.io/gh/gundestrup/jekyll-icon-flow/graph/badge.svg)](https://codecov.io/gh/gundestrup/jekyll-icon-flow)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.3-red.svg)](https://www.ruby-lang.org/)
[![Jekyll](https://img.shields.io/badge/jekyll-4.x-blue.svg)](https://jekyllrb.com/)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0--or--later-blue.svg)](LICENSE.txt)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gundestrup/jekyll-icon-flow)
[![CodeFactor](https://www.codefactor.io/repository/github/gundestrup/jekyll-icon-flow/badge)](https://www.codefactor.io/repository/github/gundestrup/jekyll-icon-flow)
[![Semgrep CE](https://img.shields.io/badge/Semgrep_CE-security-success)](https://github.com/gundestrup/jekyll-icon-flow)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=gundestrup_jekyll-icon-flow&metric=alert_status)](https://sonarcloud.io/dashboard?id=gundestrup_jekyll-icon-flow)

Pack-agnostic inline SVG icons for Jekyll via Liquid tags. Each icon pack
is an adapter that resolves names to SVG sources and normalizes the output —
so switching packs changes the icon, not your styling.

## Install

```ruby
# Gemfile
group :jekyll_plugins do
  gem "jekyll-icon-flow"
end
```

```yaml
# _config.yml
plugins:
  - jekyll-icon-flow
```

## Usage

```liquid
{% icon search %}                                → default pack (icon_flow.pack)
{% icon_lucide "file-text" size:1.5em class:"has-text-link" %}
{% icon_simple github %}
{% icon_custom logo %}
```

Fleet-convention aliases also work (`{% lucide_icon %}`, `{% simple_icon %}`,
`{% custom_icon %}`) — templates written for `jekyll-lucide` drop in
unchanged.

Same-name collisions across packs are disambiguated by the tag name —
`{% icon_lucide arrow-right %}` and `{% icon_custom arrow-right %}` can
coexist. Swap `icon_lucide` for `icon_simple` and the icon changes while
`size:`/`class:`/`title:` styling stays identical.

### Parameters

| Param | Default | Effect |
|---|---|---|
| `size:` | `m` (`1em`) | Named size `xxs`/`xs`/`s`/`m`/`l`/`xl`/`xxl` (0.5/0.75/0.875/1/1.25/1.5/2 em — relative, so icons scale with surrounding text; default `m` = 1em fits the line height) or a nonnegative CSS length (`px`, `em`, `rem`, `%`, `vw`, `vh`, `vmin`, `vmax`, `ch`, `ex`) or `0`, applied to `width`/`height` |
| `class:` | — | merged onto the `<svg>` alongside `icon icon-<name>` |
| `title:` | — | accessible label, rendered as `<title>` in the SVG |
| `pack:` | config | only on `{% icon %}` — pick a pack explicitly |

## Semantic icon names — `{% icon_ref %}`

The central-registry pattern: call sites name *intent*, one map picks the
library icon. Swap a pack and every usage follows — no template grep.

```yaml
icon_flow:
  registry:
    download: lucide:arrow-down
    github: simple:github
    danger: lucide:triangle-alert:has-text-danger   # 3rd field merges into class
```

```liquid
{% icon_ref download %}
{% icon_ref danger size:1.5em %}
```

## Packs

| Tag | Pack | License | Notes |
|---|---|---|---|
| `icon_lucide` / `lucide_icon` | [Lucide](https://lucide.dev) | ISC | UI icons, stroke style |
| `icon_simple` / `simple_icon` | [simple-icons](https://simpleicons.org) | CC0 | brand logos, fill style |
| `icon_custom` / `custom_icon` | your files | — | `icon_flow.custom_dir`, e.g. [svgrepo](https://www.svgrepo.com/) downloads (keep `-svgrepo-com.svg` attribution in filenames, per the fleet convention) |

The gem vendors a curated subset of lucide and simple-icons. Add icons
beyond the subset — or shadow any vendored icon — by dropping SVGs into
your custom dir and reaching them via `{% icon_custom %}`.

Extra packs you download wholesale (Font Awesome, Tabler, Heroicons…) get
a named pack via `icon_flow.packs` instead of mixing into the custom dir:

```yaml
icon_flow:
  packs:
    fontawesome: assets/icons/fontawesome   # dir of *.svg
    tabler: vendor/tabler/icons
```

Named packs work through `pack:` (`{% icon bars pack:fontawesome %}`), the
`{% icon %}` search chain, and `icon_flow.registry` targets
(`menu: tabler:menu`). Liquid registers tag names statically, so named
packs have no `{% icon_fontawesome %}` tag — use `{% icon %}` or
`{% icon_ref %}`.

## `{% icon %}` resolution order

The generic tag searches packs in order and renders the first hit —
default chain **custom → simple → lucide**, so `{% icon github %}` finds
the brand icon and `{% icon search %}` finds the lucide one without any
`pack:`. On collisions the earlier pack wins (`x` and `rss` exist in both
bundled packs → simple wins by default; bound tags like
`{% icon_lucide x %}` are unaffected). Pins override the chain:
`{% icon name pack:simple %}` or a configured `icon_flow.pack` restrict
the lookup to that one pack.

## Config

```yaml
icon_flow:
  enabled: true                    # false = all icon tags render nothing
  pack: null                       # pin {% icon %} to one pack; null = search chain
  search: [custom, simple, lucide] # {% icon %} resolution order (default shown)
  custom_dir: assets/icons/custom  # site-relative dir for icon_custom
  packs: {}                        # name → site-relative dir of *.svg
  on_missing: warn                 # warn (log + render "") | strict (raise)
  registry: {}                     # semantic_name → "pack:icon[:class]"
```

## Output contract

Every icon renders normalized SVG:

```html
<svg class="icon icon-search" data-icon-pack="lucide" role="img"
     style="width:1em;height:1em" …>
```

- `width`/`height` attributes are stripped; size comes from inline style
- `stroke`/`fill` normalized to `currentColor` per the pack's color model
  (`:stroke`, `:fill`, or `:auto`); custom SVG attributes on child elements
  are recolored except `none` and `url(...)` references. Inline CSS styles
  and embedded stylesheets in custom SVGs are site-owned and are not rewritten
- `icon icon-<name>` classes + `data-icon-pack` give stable CSS hooks
  that survive a pack switch
- missing/invalid icons warn via `Jekyll.logger` and render `""`
  (`on_missing: strict` fails the build instead)

## Adding a pack

1. Create `lib/jekyll/icon_flow/adapters/<pack>.rb` subclassing `Adapter`
   (`pack_name`, `path_for`, `icons_dir`, `COLOR_MODEL`).
2. Register it in `IconFlow::ADAPTERS` in `lib/jekyll/icon_flow.rb`.
3. `{% icon_<pack> %}` and `{% <pack>_icon %}` are registered automatically.

## Development and release checks

Run `bundle exec rake ci` for RuboCop, dependency audit, local Semgrep rules,
RSpec with SimpleCov and packaged-gem contents. Coverage is written to
`coverage/index.html` locally and `coverage/coverage.xml` in CI for Codecov.
`COVERAGE=false bundle exec rspec` skips instrumentation during focused work.
Run `bundle exec rake "version:bump[patch]"` to update the gem version and
lockfile, then add a dated changelog entry before
`bundle exec rake version:pre_release`. Publishing requires configuring the
GitHub `release` environment and RubyGems trusted publishing first.
SonarCloud analyses the repository automatically; its
vendored icons are excluded in `.sonarcloud.properties`.

## License

Copyright (C) 2026 Svend Gundestrup.
AGPL-3.0-or-later — see [LICENSE.txt](LICENSE.txt). Vendored icons keep
their own licenses (lucide: ISC; simple-icons: CC0-1.0).
