# 证书目录

把你的 SSL 证书放这里，供 `config.yaml` 引用（三项服务共用一张，证书只认域名不认端口）：

- `ssl.crt` — 完整证书链（fullchain / bundle）
- `ssl.key` — 私钥

例如你的证书域名是 `korea.joccboy.asia`，就把它的 bundle 重命名为 `ssl.crt`、私钥重命名为 `ssl.key` 放入本目录。

`config.yaml` 里用的是相对路径 `ssl/ssl.crt`、`ssl/ssl.key`，相对 gost 进程的工作目录（即上一级 `gost/` 目录）。用 systemd 时 `gost.service` 已把 `WorkingDirectory` 指向 `gost/`。

注意：私钥（`*.key`）已在 `.gitignore` 中忽略，不会提交到仓库。
