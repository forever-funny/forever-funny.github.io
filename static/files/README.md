# 静态附件（PDF / Word 等）

二进制附件放在本目录，**不要**放进 `content/`（content 仅放 Markdown）。

## 推荐结构

```text
static/files/
├── blog/
│   ├── tech-books/       # 技术书籍 PDF
│   ├── useful-websites/  # 如有附件
│   └── others/
└── docs/                 # 文档站其它附件（按需）
```

## 正文引用

手动链接：

```markdown
[下载 PDF](/files/blog/tech-books/示例.pdf)
```

动态清单（构建时扫描目录，增删文件后重建即可）：

```markdown
{{</* file-list dir="files/blog/tech-books" ext=".pdf" */>}}
```

短代码定义在 `layouts/_shortcodes/file-list.html`。站点根路径 `/files/...` 对应本目录。
