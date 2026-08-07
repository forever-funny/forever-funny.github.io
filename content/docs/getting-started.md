---
title: 入门指南
weight: 1
---

# 入门指南

## 环境要求

- Hugo Extended（本仓库本地开发已用 `v0.164.0` 验证）
- Git

本方案**不需要**安装 Go：主题位于 `themes/hugo-book`，未使用 Hugo Modules。

## 克隆与预览

```bash
git clone https://github.com/forever-funny/forever-funny.github.io.git
cd forever-funny.github.io
hugo server -D
```

## 新增文档

1. 在 `content/docs/`（或其子目录）下创建 `.md` 文件
2. 多级目录：每一级放一个 `_index.md` 作为菜单节点（示例：`content/docs/bonree/rum/`）
3. 写好 front matter（至少包含 `title`，可用 `weight` 控制排序）
4. 保存后本地预览会自动刷新

详见「写作规范」。
