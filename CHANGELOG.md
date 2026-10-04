# Changelog

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
- Escape Liquid-supplied SVG attributes, validate icon sizes, and normalize child SVG colors.
- RSpec integration/adapter contracts, coverage reporting, Semgrep and gem-artifact checks.
