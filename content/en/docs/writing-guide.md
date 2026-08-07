---
title: Writing guide
weight: 2
---

# Writing guide

## Content layout

| Path | Purpose |
|------|---------|
| `content/zh-cn/` | Chinese content (default) |
| `content/en/` | English content |
| `content/*/docs/` | Documentation body (Hextra sidebar) |
| `static/` | Static assets |
| `hugo.toml` | Site and theme config |

## New page

```yaml
---
title: Page title
weight: 10
---

# Page title

Body…
```

## Nested sections

Each directory needs an `_index.md` menu node:

```text
content/en/docs/
├── _index.md
└── example/
    ├── _index.md
    └── overview.md
```

## Front matter

- `title`: page title (required for a clean sidebar label)
- `weight`: sidebar order (lower first)
- `sidebar.exclude: true`: hide from sidebar (useful for meta pages)
