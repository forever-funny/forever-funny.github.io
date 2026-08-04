---
title: 入门指南
weight: 1
---

# 入门指南

## 环境要求

- [Hugo Extended](https://gohugo.io/installation/)（本仓库使用 Extended 版）
- Git

不需要安装 Go：主题位于 `themes/hugo-book`，日常预览与构建不依赖 Go。

## 本地预览

```bash
hugo server -D
```

浏览器打开提示的本地地址（默认 `http://localhost:1313/`）。

## 新增文档

1. 在 `content/docs/` 下新建 Markdown 文件
2. 填写 front matter（至少包含 `title`）
3. 保存后，Hugo 会自动刷新页面与侧边栏

示例：

```markdown
---
title: 我的新页面
weight: 10
---

# 我的新页面

正文内容……
```
