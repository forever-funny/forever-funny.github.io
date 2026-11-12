---
title: 写作规范
weight: 2
aliases:
  - /zh-cn/docs/writing-guide/
description: 目录约定、URL、front matter 与多语言写作规范
---

## 目录结构

| 路径 | 用途 |
|------|------|
| `content/zh-cn/` | 中文内容（默认语言，站点根路径） |
| `content/en/` | 英文内容（`/en/`） |
| `content/*/docs/` | 笔记（带左侧目录） |
| `content/*/blog/` | 随笔（子目录：`useful-websites` / `tech-books` / `others`） |
| `static/images/` | logo、分享图与插图 |
| `assets/css/custom.css` | 站点样式覆盖 |
| `hugo.toml` | 站点与主题配置 |

## 目录与 URL 约定（重要）

- **物理目录只用** `a-z`、`0-9`、`-`（kebab-case），不要空格、不要中文路径名。
- 展示名写在 front matter 的 `title` 里。
- 卡片与正文链接写 **slug**（如 `getting-started`），不要写文件夹显示名。
- 改名时在 front matter 加 `aliases`，避免旧链接 404。

```text
# 推荐
content/zh-cn/docs/getting-started.md   ->  /docs/getting-started/

# 不推荐（空格会导致 URL 与实际 slug 不一致）
content/zh-cn/docs/Getting Started.md
```

## URL 结构

- 中文是默认语言，直接位于根路径：`/`、`/docs/`、`/blog/`。
- 英文位于 `/en/` 前缀下：`/en/docs/`、`/en/blog/`。
- 从 `/zh-cn/...` 迁到根路径时，每个中文页都通过 `aliases` 保留了旧地址跳转。

## 新增一篇笔记

```bash
hugo new content/zh-cn/docs/example-topic/overview.md
```

或手写 front matter：

```yaml
---
title: 页面标题
weight: 10
description: 一句话摘要（SEO / 列表卡片）
---

## 第一节

正文从二级标题（`##`）开始……
```

## 标题不要重复（重要）

Hextra 会用 front matter 的 `title` 自动渲染页眉 `<h1>`。
因此正文里**不要**再写与 `title` 相同的 `# 一级标题`，否则页面顶部会出现两行相同文字。

| 正确 | 错误 |
|------|------|
| `title: 写作规范`，正文从 `## ...` 起 | `title` 与正文 `# 写作规范` 同时存在 |

## 新增多级目录

每一级都需要 `_index.md`：

```text
content/zh-cn/docs/
├── _index.md
└── example-topic/
    ├── _index.md
    └── overview.md
```

## Front Matter 常用字段

| 字段 | 说明 |
|------|------|
| `title` | **必填**。页面标题（侧栏、浏览器标题、页眉 h1）；缺省时侧栏会回退为文件名 |
| `weight` | 侧栏排序，越小越靠前 |
| `description` | 摘要 |
| `draft` | `true` 时生产构建默认不输出（本地用 `hugo server -D`） |
| `sidebar.exclude` | `true` 时不进左侧菜单（元文档、协议） |
| `llms` | `false` 时不进入 `llms.txt`（内部知识） |
| `toc` | `false` 关闭右侧目录 |
| `aliases` | 旧 URL 别名列表 |
| `tags` | 博客等可打标签 |

## 多语言

- 中文写在 `content/zh-cn/`，英文写在 `content/en/`，**尽量保持相对路径一致**（语言切换会落到同路径的对应页）。
- 只有一种语言的内容，另一侧应补一份入口说明，避免语言切换落到 404。
- 语言切换依赖两边路径一致：新增中文页时，记得确认英文侧是否存在同名路径。

## 样式与短代码

- 图片放 `static/images/`，正文用 `/images/xxx.png`。
- 站点不再托管 PDF / Word 等大文件；书目类内容直接写成 Markdown 列表。
- 首页、卡片、提示等功能优先用 Hextra 短代码（`cards`、`callout`、`steps`、`tabs`、`hextra/feature-grid` 等）。
- 样式微调改 `assets/css/custom.css`，不要直接改 `_vendor/`。
- 正文里可用的 Tailwind 工具类只包括主题已编译的那些；不确定时改用 `custom.css` 里的语义类（如 `site-hero-actions`）。

## 提交前

本地执行 `hugo --minify`，确认无报错；抽查关键页与语言切换。
