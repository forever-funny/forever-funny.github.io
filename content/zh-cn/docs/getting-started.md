---
title: 入门指南
weight: 1
description: 环境要求、本地预览与新增文档
---

## 环境要求

- Hugo Extended（本仓库本地开发已用 `v0.164.0` 验证）
- Git
- Go（用于 Hugo Modules 拉取/同步主题；仓库已 vendor `hextra`，日常预览通常可直接运行）

主题为 [Hextra](https://github.com/imfing/hextra)（Hugo Module）。

## 克隆与预览

```bash
git clone https://github.com/forever-funny/forever-funny.github.io.git
cd forever-funny.github.io
hugo server -D
```

## 新增文档

1. 中文文档写在 `content/zh-cn/docs/`，英文写在 `content/en/docs/`
2. 多级目录：每一级放一个 `_index.md` 作为菜单节点（示例：`content/zh-cn/docs/aaa/`）
3. 写好 front matter（至少包含 `title`，可用 `weight` 控制排序）
4. 保存后本地预览会自动刷新

默认语言为中文（`/zh-cn/`），顶栏可切换 English（`/en/`）。详见「写作规范」。
