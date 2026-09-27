# jekyll-icon-flow

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
| `size:` | `1em` | CSS size applied as inline `width`/`height` |
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

## Config

```yaml
icon_flow:
  enabled: true                    # false = all icon tags render nothing
  pack: lucide                     # default pack for {% icon %}
  custom_dir: assets/icons/custom  # site-relative dir for icon_custom
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
  (`:stroke`, `:fill`, or `:auto`) so `color:` CSS works identically
- `icon icon-<name>` classes + `data-icon-pack` give stable CSS hooks
  that survive a pack switch
- missing/invalid icons warn via `Jekyll.logger` and render `""`
  (`on_missing: strict` fails the build instead)

## Adding a pack

1. Create `lib/jekyll/icon_flow/adapters/<pack>.rb` subclassing `Adapter`
   (`pack_name`, `path_for`, `icons_dir`, `COLOR_MODEL`).
2. Register it in `IconFlow::ADAPTERS` in `lib/jekyll/icon_flow.rb`.
3. `{% icon_<pack> %}` and `{% <pack>_icon %}` are registered automatically.

## License

AGPL-3.0-or-later. Vendored icons keep their own licenses
(lucide: ISC; simple-icons: CC0-1.0).
