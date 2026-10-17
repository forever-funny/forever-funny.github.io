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

浏览器打开终端提示的地址（默认 `http://localhost:1313/` → 通常跳到 `/zh-cn/`）。

本地构建：

```powershell
hugo --minify
```

产物在 `public/`（已加入 `.gitignore`，不要提交）。

## 文档怎么写

- 中文：`content/zh-cn/`；英文：`content/en/`（URL 带语言前缀）
- 正式文档：`docs/`；变更日志：`blog/`
- 目录名用 kebab-case；详见各语言「写作规范」

## 已预留能力

| 能力 | 位置 / 开关 |
|------|-------------|
| 多语言 | `content/zh-cn`、`content/en` |
| Logo | `static/images/` + `params.navbar.logo`（`displayLogo` 暂为 false） |
| 自定义样式 | `assets/css/custom.css` |
| Edit on GitHub | `params.editURL` |
| llms.txt / Markdown | `[outputs]` + 页面「复制 Markdown」菜单 |
| 公告条 | `params.banner`（默认注释） |
| 博客 section | `content/*/blog/` |

## 发布到 GitHub Pages

仓库已预置 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)。

1. 推送到 `main`
2. Settings → Pages → Source 选 **GitHub Actions**
3. 站点发布在 https://forever-funny.github.io/

网络不稳时可用重试脚本（以脚本所在目录为仓库根，失败按间隔重试直至成功）：

```bash
./git-retry.sh push          # 默认: git push -u origin HEAD
./git-retry.sh pull          # 默认: git pull
```

环境变量：`GIT_RETRY_INTERVAL`（秒，默认 1）、`GIT_REMOTE`（push 无参时默认 `origin`）。

## 目录结构（摘要）

```text
forever-funny/
├── .github/workflows/pages.yml
├── archetypes/default.md
├── assets/css/custom.css
├── content/
│   ├── zh-cn/          # docs + blog
│   └── en/
├── static/images/
├── static/files/
├── _vendor/            # Hextra module 缓存
├── git-retry.sh / git-retry.bat
├── hugo.toml
├── go.mod / go.sum
└── README.md
```
