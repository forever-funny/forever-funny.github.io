# Forever Funny

基于 [Hugo](https://gohugo.io/) + [hugo-book](https://github.com/alex-shpak/hugo-book) 的个人文档站。

- 本地工程目录：`forever-funny`
- 远程仓库名：`forever-funny.github.io`（GitHub User Site）
- 预期线上地址：<https://forever-funny.github.io/>

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

浏览器打开提示地址（默认 `http://localhost:1313/`）。

生产构建：

```powershell
hugo --minify
```

产物在 `public/`（已加入 `.gitignore`，勿提交）。

## 文档怎么写

- 首页：`content/_index.md`
- 文档正文：`content/docs/*.md`（侧边栏由此自动生成）
- 站点配置：`hugo.toml`
- 主题目录：`themes/hugo-book`（已内置 alex-shpak/hugo-book，无需再装 Go / Modules）

新建页面示例：

```markdown
---
title: 页面标题
weight: 10
---

# 页面标题

正文……
```

## 发布到 GitHub Pages（你稍后完成）

本仓库已预置 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)，push 到 `main` 后可自动构建并部署。

1. 在 GitHub 账号 **`forever-funny`** 下创建空仓库 **`forever-funny.github.io`**（不要勾选自动生成 README）。
2. 在本机添加远程并推送：

```powershell
git remote add origin https://github.com/forever-funny/forever-funny.github.io.git
git add .
git commit -m "Initial Hugo docs site"
git push -u origin main
```

3. 打开仓库 **Settings → Pages → Build and deployment → Source**，选择 **GitHub Actions**。
4. 在 **Actions** 中确认 workflow 成功；站点发布在 <https://forever-funny.github.io/>。

> User Site 要求：仓库名必须严格等于 `<账号名>.github.io`。若账号不是 `forever-funny`，请同步修改仓库名与 `hugo.toml` 中的 `baseURL` / `BookRepo`。

## 主题说明

因本机拉取 git submodule 不稳定，主题以文件形式放在 `themes/hugo-book`（源自 [alex-shpak/hugo-book](https://github.com/alex-shpak/hugo-book)）。若你希望改为 submodule，可自行替换：

```powershell
Remove-Item -Recurse -Force themes/hugo-book
git submodule add https://github.com/alex-shpak/hugo-book themes/hugo-book
```
