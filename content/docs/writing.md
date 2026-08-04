---
title: 写作规范
weight: 2
---

# 写作规范

## Front Matter

每篇文档建议包含：

```yaml
---
title: 页面标题
weight: 10
---
```

- `title`：侧边栏与页面标题
- `weight`：同级排序，数字越小越靠前

## Markdown

- 一级标题与 `title` 保持一致或互补
- 代码块标明语言，便于高亮
- 需要目录时保持合理的标题层级（`##` / `###`）

## 发布

推送到 `main` 后，由 GitHub Actions 构建并发布到 [https://forever-funny.github.io/](https://forever-funny.github.io/)。
