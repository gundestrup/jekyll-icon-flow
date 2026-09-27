# Changelog

## 0.1.0 (unreleased)

- `{% icon %}` + per-pack `{% icon_<pack> %}` Liquid tags (lucide,
  simple-icons, custom dir) with fleet-convention aliases
  (`{% lucide_icon %}` etc.)
- `{% icon_ref <key> %}` — semantic names resolved through
  `icon_flow.registry` (`pack:name[:class]` entries)
- Normalized output contract: `icon icon-<name>` classes, `currentColor`,
  inline `1em` sizing, `data-icon-pack` hook
- `icon_flow.on_missing: warn|strict` — warn + empty render by default
