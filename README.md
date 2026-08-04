# Forever Funny

基于 **Hugo + hugo-book** 的个人文档站。

- 本地工程目录：`forever-funny`
- 远程仓库名：`forever-funny.github.io`（GitHub User Site）
- 预期线上地址：https://forever-funny.github.io/

## 环境准备

安装 **Hugo Extended**（不要用非 Extended 版）：

```powershell
winget install Hugo.Hugo.Extended
```

或从 [Hugo Releases](https://github.com/gohugoio/hugo/releases) 下载 `hugo_extended_*_windows-amd64.zip`，将 `hugo.exe` 加入 PATH。

验证：

```powershell
hugo version
```

输出中应包含 `extended`。日常本地预览/构建**不需要**安装 Go。

## 本地预览

```powershell
cd forever-funny
hugo server -D
```

浏览器打开终端提示的地址（默认 `http://localhost:1313/`）。

本地构建：

```powershell
hugo --minify
```

产物在 `public/`（已加入 `.gitignore`，不要提交）。

## 主题说明

主题 [hugo-book](https://github.com/alex-shpak/hugo-book) 已放入 `themes/hugo-book/`（仓库内 vendored，避免本机拉取 git submodule 不稳定）。更新主题时可替换该目录内容。

## 文档怎么写

- 文档放在 `content/docs/`
- 每篇 Markdown 使用 front matter，例如：

```yaml
---
title: 页面标题
weight: 10
---
```

- `weight` 控制侧边栏排序（越小越靠前）
- 更多约定见站点内「写作规范」页

## 发布到 GitHub Pages（稍后你自己完成）

本仓库已预置 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)，**不会**自动创建远程仓库。你需要：

### 1. 在 GitHub 创建空仓库

账号/组织：`forever-funny`  
仓库名：**`forever-funny.github.io`**（User Site 要求仓库名等于 `<账号>.github.io`）

### 2. 关联远程并推送

在本地工程根目录：

```bash
git remote add origin https://github.com/forever-funny/forever-funny.github.io.git
git add .
git commit -m "Initial Hugo documentation site"
git push -u origin main
```

### 3. 启用 Pages

仓库 → **Settings** → **Pages** → **Build and deployment** → **Source** 选择 **GitHub Actions**。

### 4. 确认上线

Actions 跑通后，站点应发布在：

https://forever-funny.github.io/

> 若实际 GitHub 用户名不是 `forever-funny`，则不能把仓库命名为 `forever-funny.github.io` 作为 User Site；需要把账号名与仓库名改成一致的 `<user>.github.io`，并同步修改 `hugo.toml` 中的 `baseURL` / `BookRepo`。

## 目录结构（摘要）

```text
forever-funny/
├── .github/workflows/pages.yml   # Pages 自动部署
├── content/
│   ├── _index.md                 # 首页
│   └── docs/                     # 文档（侧边栏）
├── themes/hugo-book/             # hugo-book 主题
├── hugo.toml                     # 站点配置
└── README.md
```
