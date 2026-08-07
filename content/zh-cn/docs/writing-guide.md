---
title: 写作规范
weight: 2
description: 目录约定、URL、front matter 与多语言写作规范
---

## 目录结构

| 路径 | 用途 |
|------|------|
| `content/zh-cn/` | 中文内容（默认语言） |
| `content/en/` | 英文内容 |
| `content/*/docs/` | 正式文档（侧边栏） |
| `content/*/blog/` | 博客（子目录：`useful-websites` / `tech-books` / `others`） |
| `static/images/` | logo 与插图 |
| `static/files/` | PDF / Word 等附件（按栏目分子目录，如 `files/blog/tech-books/`） |
| `assets/css/custom.css` | 站点样式覆盖 |
| `hugo.toml` | 站点与主题配置 |

## 目录与 URL 约定（重要）

- **物理目录只用** `a-z`、`0-9`、`-`（kebab-case），不要空格、不要中文路径名。
- 展示名写在 front matter 的 `title` 里。
- 卡片与正文链接写 **slug**（如 `digital-experience`），不要写文件夹显示名。
- 改名时在 front matter 加 `aliases`，避免旧链接 404。

```text
# 推荐
content/zh-cn/docs/digital-experience/rum/...

# 不推荐（空格会导致 /Digital%20Experience 与实际 slug 不一致）
content/zh-cn/docs/Digital Experience/...
```

> 历史目录 `Digital Experience` 仍保留；**新建**目录请一律用 kebab-case。

## 新增一篇文档

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
└── example-product/
    ├── _index.md
    └── rum/
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

- 中文写在 `content/zh-cn/`，英文写在 `content/en/`，**尽量保持相对路径一致**（便于语言切换落到对应页）。
- 内部知识库（如 RUM）可仅维护中文；英文侧用入口页说明并链到中文即可。
- 站点 URL 带语言前缀：`/zh-cn/...`、`/en/...`。

## 资源与短代码

- 图片放 `static/images/`，正文用 `/images/xxx.png`。
- PDF / Word 等放 `static/files/...`，正文用 `/files/...` 链接下载；**不要**把二进制文件放进 `content/`。
- 需要自动清单时用短代码：`{{</* file-list dir="files/blog/tech-books" ext=".pdf" */>}}`（构建时扫描目录）。
- 流程图优先 Mermaid；步骤、提示用 Hextra 短代码（`cards`、`callout`、`steps`、`tabs` 等）。
- 样式微调改 `assets/css/custom.css`，不要直接改 `_vendor/`。

## 提交前

本地执行 `hugo --minify`，确认无报错；抽查关键页与语言切换。
