# Runbook：Nginx 上游配置错误

## 1. 场景说明

这是一个故意注入的故障场景：让 Nginx 的 `proxy_pass` 指向错误的上游端口，例如 `web:5999`。

对应脚本：

- 注入：`./scripts/drill_nginx_bad_upstream.sh`
- 恢复：`./scripts/recover_nginx_bad_upstream.sh`

## 2. 典型现象

- `db` 正常
- `web` 正常
- `nginx` 也正常运行
- 页面访问返回 `502`
- `nginx -t` 仍可能通过，因为这是逻辑错误，不是语法错误
- `nginx` 日志里会看到 upstream 连接失败 / connection refused 等信息

## 3. 排查顺序

### 第一步：看 HTTP 状态

```bash
./scripts/health_check.sh
```

如果页面返回 `502`，先不要直接判断是 Flask 或数据库坏了。

### 第二步：确认 web 容器是否正常

在 `health_check.sh` 输出里看：

- `web` 是否 `Up`
- `web` 日志是否正常

如果 `web` 正常，问题可能就在 Nginx 到 web 这条链路。

### 第三步：看 Nginx 日志

```bash
cd ../support-demo-platform
docker compose logs --tail=80 nginx
```

如果日志提示 upstream 连接失败，说明：

- Nginx 收到了请求
- 但转发目标不对，或上游不可达

## 4. 故障恢复

执行：

```bash
./scripts/recover_nginx_bad_upstream.sh
./scripts/health_check.sh
```

恢复后应重新回到：

- HTTP `200`
- Nginx 正常代理

## 5. 结论模板

> 502 代表 Nginx 收到了请求，但无法从上游应用拿到有效响应。排查时要先区分是上游地址写错、上游端口不通，还是上游服务本身没起来。
