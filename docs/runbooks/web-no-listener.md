# Runbook：web 容器无监听端口

## 1. 场景说明

这是一个故意注入的故障场景：让 `web` 容器保持运行，但不启动 Flask，因此容器内 `127.0.0.1:5000` 无监听。

对应脚本：

- 注入：`./scripts/drill_web_no_listener.sh`
- 恢复：`./scripts/recover_web_no_listener.sh`

## 2. 典型现象

- `db` 正常
- `nginx` 正常
- `web` 容器可能仍显示 `Up`
- 页面访问异常，常见为 `502`
- `nginx` 配置检查正常
- `health_check.sh` 会明确提示：`web 容器内 127.0.0.1:5000 未监听`

## 3. 这类问题为什么容易误判

因为它和 “Nginx 上游配置错误” 的表面现象很像：

- 页面都可能是 `502`
- Nginx 自己也还在运行

但两者根因不同：

- 上游配置错误：Nginx 指向错地址
- 端口未监听：Nginx 指向没错，但目标端口没人接收连接

## 4. 排查顺序

### 第一步：跑巡检

```bash
./scripts/health_check.sh
```

重点看：

- HTTP 是否失败
- Nginx 配置是否正常
- `web` 容器内 `5000` 是否监听

### 第二步：确认 `web` 容器内端口状态

如果想单独验证，可执行：

```bash
cd ../support-demo-platform
docker compose exec -T web python - <<'PY'
import socket
s = socket.socket()
s.settimeout(2)
print(s.connect_ex(("127.0.0.1", 5000)))
PY
```

返回非 `0` 时，通常说明目标端口没人监听。

### 第三步：看 web 日志

```bash
cd ../support-demo-platform
docker compose logs --tail=40 web
```

这类故障中，`web` 日志通常不会有正常 Flask 启动信息。

## 5. 故障恢复

执行：

```bash
./scripts/recover_web_no_listener.sh
./scripts/health_check.sh
```

恢复后应重新看到：

- `web` 容器内 `5000` 正在监听
- HTTP 返回 `200`

## 6. 结论模板

> 排查容器化应用时，不能只看容器是不是 `Up`。容器在运行，不代表服务真的可用。很多问题的关键不是容器状态，而是容器内关键端口是否真的有人监听。
