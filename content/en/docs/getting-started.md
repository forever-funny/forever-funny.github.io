---
title: Getting started
weight: 1
---

## Requirements

- Hugo Extended (verified locally with `v0.164.0`)
- Git
- Go (for Hugo Modules; this repo vendors `hextra` under `_vendor/`)

Theme: [Hextra](https://github.com/imfing/hextra) (Hugo Module).

## Clone and preview

```bash
git clone https://github.com/forever-funny/forever-funny.github.io.git
cd forever-funny.github.io
hugo server -D
```

Default language is Chinese (`/`). English pages are under `/en/`.

## Add a page

1. Create a `.md` file under `content/en/docs/` (or a subdirectory)
2. For nested sections, add `_index.md` at each level
3. Set front matter (`title`, optional `weight`)
4. Save — the local server reloads automatically

See the writing guide for conventions.
