# 品牌与图片资源

FF 字标由几何矩形拼成，SVG 与 PNG/ICO 来自同一套坐标，改动后请重新生成：

```powershell
python scripts/gen-brand-assets.py
```

| 文件 | 用途 |
|------|------|
| `logo.svg` | 顶栏 logo（浅色模式） |
| `logo-dark.svg` | 顶栏 logo（深色模式） |
| `og.png` | 1200×630 社交分享图，由 `params.images` 引用 |
| 其他 | 文档插图，正文用 `/images/xxx.png` 引用 |

favicon 与 PWA 图标在仓库根 `static/`（`favicon.svg`、`favicon.ico`、`favicon-16x16.png`、`favicon-32x32.png`、`apple-touch-icon.png`、`android-chrome-*.png`、`site.webmanifest`），同名文件会覆盖 Hextra 主题自带的默认图标。
