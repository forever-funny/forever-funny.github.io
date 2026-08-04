---
title: 写作规范
weight: 2
---

# 写作规范

## 目录结构

| 路径 | 用途 |
|------|------|
| `content/_index.md` | 站点首页 |
| `content/docs/` | 文档正文（侧边栏来源） |
| `static/` | 静态资源（图片、附件等） |
| `hugo.toml` | 站点与主题配置 |

## Front Matter 常用字段

- `title`：页面标题（必填）
- `weight`：侧边栏排序，数字越小越靠前
- `draft`：设为 `true` 时默认不参与生产构建（本地可用 `hugo server -D` 预览）

## 建议

- 一篇文档只讲一件事，标题与文件名保持语义一致
- 图片放到 `static/images/`，正文中用 `/images/xxx.png` 引用
- 提交前本地执行 `hugo --minify`，确认构建无报错
