---
title: 写作规范
weight: 2
---

## 目录结构

| 路径 | 用途 |
|------|------|
| `content/zh-cn/` | 中文内容（默认语言） |
| `content/en/` | 英文内容 |
| `content/*/docs/` | 文档正文（Hextra 侧边栏由此生成） |
| `static/` | 静态资源（图片、附件等） |
| `hugo.toml` | 站点与主题配置（Hextra Module） |

多级目录请建在对应语言的 `docs/` 内。

## 新增一篇文档

在 `content/zh-cn/docs/` 或 `content/en/docs/`（或其子目录）新建 `.md`：

```yaml
---
title: 页面标题
weight: 10
---

# 页面标题

正文……
```

## 新增多级目录

每一级目录都需要 `_index.md` 作为菜单节点：

```text
content/zh-cn/docs/
├── _index.md
└── Digital Experience/
    ├── _index.md
    └── rum/
        ├── _index.md
        └── overview.md
```

## Front Matter 常用字段

- `title`：页面标题（必填）
- `weight`：侧边栏排序，数字越小越靠前
- `draft`：设为 `true` 时默认不参与生产构建（本地可用 `hugo server -D` 预览）
- `sidebar.exclude`：设为 `true` 时不出现在左侧菜单
- `toc: false`：关闭右侧目录

## 建议

- 一篇文档只讲一件事，标题与文件名保持语义一致
- 图片放到 `static/images/`，正文中用 `/images/xxx.png` 引用
- 提交前本地执行 `hugo --minify`，确认构建无报错
