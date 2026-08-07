# Forever Funny

基于 **Hugo + [Hextra](https://github.com/imfing/hextra)** 的个人文档站。

- 本地工程目录：`forever-funny`
- 远程仓库名：`forever-funny.github.io`（GitHub User Site）
- 预期线上地址：https://forever-funny.github.io/

## 环境准备

安装 **Hugo Extended**：

```powershell
winget install Hugo.Hugo.Extended
```

验证：

```powershell
hugo version
```

输出中应包含 `extended`。主题通过 Hugo Module 引入，并已 `hugo mod vendor` 到 `_vendor/`；日常预览一般无需再拉依赖。若要更新主题：

```powershell
hugo mod get -u github.com/imfing/hextra
hugo mod vendor
```

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

## 文档怎么写

- 中文：`content/zh-cn/`；英文：`content/en/`（默认语言 `zh-cn`，URL 带语言前缀）
- 文档正文在各语言的 `docs/` 下；每篇 Markdown 使用 front matter（`title` / `weight`）
- RUM 知识库在 `content/zh-cn/docs/Digital Experience/rum/`

## 发布到 GitHub Pages

仓库已预置 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)。

1. 推送到 `main`
2. Settings → Pages → Source 选 **GitHub Actions**
3. 站点发布在 https://forever-funny.github.io/

## 目录结构（摘要）

```text
forever-funny/
├── .github/workflows/pages.yml
├── content/
│   ├── _index.md
│   └── docs/
├── _vendor/                      # Hextra 等 module 缓存
├── hugo.toml
├── go.mod / go.sum
└── README.md
```
