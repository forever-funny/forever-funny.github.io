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

1. 在 `content/docs/` 下创建 `.md` 文件
2. 写好 front matter（至少包含 `title`，可用 `weight` 控制排序）
3. 保存后本地预览会自动刷新
