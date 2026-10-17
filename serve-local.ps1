# 本地开发预览：搜索库走国内镜像 (hugo.local.toml)，避免 jsdelivr 连接被重置。
# 用法：在仓库根目录执行  pwsh serve-local.ps1   （或 ./serve-local.ps1）
hugo server -D --config hugo.toml,hugo.local.toml
