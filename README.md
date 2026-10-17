# Forever Funny

基于 **Hugo + [Hextra](https://github.com/imfing/hextra)** 的个人网站。首页是落地页；知识库在 `docs/`，随笔在 `blog/`。

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

内容变更后，用下面的命令启动才能在本地看到最新结果。默认的快速渲染可能只重做当前页，改过的其他页面仍是旧的。

```powershell
cd forever-funny
hugo server -D --disableFastRender
```

浏览器打开终端提示的地址（默认 `http://localhost:1313/` → 通常跳到 `/zh-cn/`）。改完后在浏览器里强制刷新一次（Ctrl+F5）。若已有旧的 `hugo server` 在跑，先停掉再执行上述命令。

清理并重建本地编译产物。`--cleanDestinationDir` 会先清空 `public/`，再按当前内容整站生成：

```powershell
hugo --minify --cleanDestinationDir
```

产物在 `public/`（已加入 `.gitignore`，不要提交）。`hugo server` 默认在内存里预览，不会自动更新这份目录。

## 文档怎么写

- 中文：`content/zh-cn/`；英文：`content/en/`（URL 带语言前缀）
- 首页、关于、项目：`_index.md`、`about.md`、`projects.md`
- 知识库：`docs/`；随笔：`blog/`
- 目录名用 kebab-case；详见各语言「写作规范」

## 已预留能力

| 能力 | 位置 / 开关 |
|------|-------------|
| 多语言 | `content/zh-cn`、`content/en` |
| Logo | `static/images/logo.svg`、`logo-dark.svg`（顶栏已开启） |
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
│   ├── zh-cn/          # 首页、关于、项目、docs、blog
│   └── en/
├── static/images/
├── static/files/
├── _vendor/            # Hextra module 缓存
├── git-retry.sh / git-retry.bat
├── hugo.toml
├── go.mod / go.sum
└── README.md
```
