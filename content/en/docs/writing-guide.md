---
title: Writing guide
weight: 2
description: Directory layout, URL rules, front matter, and i18n conventions
---

# Writing guide

## Content layout

| Path | Purpose |
|------|---------|
| `content/zh-cn/` | Chinese (default) |
| `content/en/` | English |
| `content/*/docs/` | Documentation (sidebar) |
| `content/*/blog/` | Changelog / announcements |
| `static/images/` | Logos and images |
| `assets/css/custom.css` | Theme overrides |
| `hugo.toml` | Site config |

## Directory and URL rules

- Use kebab-case folder names (`a-z`, `0-9`, `-`) only — no spaces, no non-ASCII path segments.
- Put the display name in `title`.
- Link with the **slug** (e.g. `digital-experience`), not the raw folder label.
- When renaming, add `aliases` so old URLs keep working.

## New page

```bash
hugo new content/en/docs/example-topic/overview.md
```

```yaml
---
title: Page title
weight: 10
description: One-line summary
---
```

## Nested sections

Every directory needs `_index.md`.

## Front matter

| Field | Meaning |
|-------|---------|
| `title` | Page title |
| `weight` | Sidebar order |
| `description` | Summary |
| `draft` | Hide from production builds |
| `sidebar.exclude` | Hide from sidebar |
| `llms` | Set `false` to exclude from `llms.txt` |
| `aliases` | Old URL redirects |
| `tags` | Optional taxonomy (blog) |

## i18n

Keep relative paths aligned across `zh-cn` and `en` when a translation exists. Internal knowledge bases may stay Chinese-only; English can link to them.

## Before commit

Run `hugo --minify` and spot-check language switching.
