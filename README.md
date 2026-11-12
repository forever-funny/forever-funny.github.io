# Forever Funny

基于 **Hugo + [Hextra](https://github.com/imfing/hextra)** 的双语个人网站。首页是落地页，笔记在 `docs/`，随笔在 `blog/`。

- 本地工程目录：`forever-funny`
- 远程仓库名：`forever-funny.github.io`（GitHub User Site）
- 线上地址：https://forever-funny.github.io/
- 中文在根路径 `/`，英文在 `/en/`；旧的 `/zh-cn/**` 链接通过 `aliases` 跳转

## 环境准备

安装 **Hugo Extended**：

```powershell
winget install Hugo.Hugo.Extended
hugo version   # 输出中应包含 extended
```

主题通过 Hugo Module 引入，并已 `hugo mod vendor` 到 `_vendor/`，日常预览无需再拉依赖。更新主题：

```powershell
hugo mod get -u github.com/imfing/hextra
hugo mod vendor
```

## 本地预览

```powershell
hugo server -D --disableFastRender
```

打开 `http://localhost:1313/`。请使用 `localhost`（而不是 `127.0.0.1`），否则「复制页面」拉取 `.md` 时会被 CORS 拦住。改完强制刷新一次（Ctrl+F5）。

构建产物并清理旧文件：

```powershell
hugo --minify --cleanDestinationDir
node scripts/check-links.mjs public
```

`public/` 已加入 `.gitignore`，不要提交。`hugo server` 默认在内存里预览，不会更新这份目录。

## 内容布局与 URL

| 中文 URL | 英文 URL | 内容 |
|----------|----------|------|
| `/` | `/en/` | 首页（hero + 四张入口卡片） |
| `/about/` | `/en/about/` | 关于 |
| `/projects/` | `/en/projects/` | 项目 |
| `/docs/` | `/en/docs/` | 笔记（带左侧目录） |
| `/blog/` | `/en/blog/` | 随笔：常用网站 / 技术书籍 / 其它 |

- 中文：`content/zh-cn/`；英文：`content/en/`。
- 笔记是 `docs/`，随笔是 `blog/`，两边的相对路径尽量保持一致，语言切换才能落到对应页。
- 写作约定见 <https://forever-funny.github.io/docs/writing-guide/>。

## 新增内容

```powershell
hugo new content/zh-cn/docs/example-topic/overview.md
```

front matter 至少写 `title`，可用 `weight` 控制侧栏顺序。每级目录放一个 `_index.md` 作为菜单节点。

> 正文里可用的 `hx:` 工具类只包括主题已编译的那些。需要新样式时写进 `assets/css/custom.css` 的语义类（例如 `site-hero-actions`），不要依赖未编译的 Tailwind 类。

## 品牌资源

FF 字标、favicon、PWA 图标和 1200×630 分享图由同一套几何坐标生成：

```powershell
python scripts/gen-brand-assets.py
```

需要 Pillow。输出覆盖 `static/images/logo*.svg`、`static/images/og.png`、根目录 favicon 系列与 `static/site.webmanifest`。

## 附件与体积

站点不再托管 PDF / Word 等大文件，`static/files/` 已移除；技术书籍页只保留书目。历史 PDF 仍存在于 git 历史中，clone 体积不会因此变小；如需彻底瘦身需单独重写历史。

## 发布到 GitHub Pages

仓库已预置 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)：

1. 推送到 `main`
2. Settings → Pages → Source 选 **GitHub Actions**
3. 构建阶段会执行 `hugo --printPathWarnings` 和 `node scripts/check-links.mjs ./public`，有内链 404 会直接失败

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
├── assets/css/custom.css        # 主色、阅读宽度、标题对齐、hero 间距
├── content/
│   ├── zh-cn/                  # 首页、关于、项目、docs、blog
│   └── en/
├── layouts/
│   ├── 404.html                # 双语 404，带站点导航
│   └── robots.txt              # 含 Sitemap
├── scripts/
│   ├── check-links.mjs         # 构建产物内链检查（CI 也用）
│   └── gen-brand-assets.py     # 生成 FF 图标与分享图
├── static/images/              # logo、og 分享图、插图
├── _vendor/                    # Hextra module 缓存
├── git-retry.sh
├── hugo.toml
├── go.mod / go.sum
└── README.md
```
