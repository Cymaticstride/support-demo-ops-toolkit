# Runbook：数据库认证失败

## 1. 场景说明

这是一个故意注入的故障场景：给 `web` 服务写入错误的数据库密码，导致应用无法正常连接 MySQL。

对应脚本：

- 注入：`./scripts/drill_db_auth_fail.sh`
- 恢复：`./scripts/recover_db_auth_fail.sh`

## 2. 典型现象

- `db` 容器通常仍是 `healthy`
- `nginx` 容器通常仍在运行
- `web` 可能重启失败、退出，或长时间起不来
- 页面访问失败，可能不是 `200`
- `health_check.sh` 中 `web` 日志会出现数据库连接失败、认证失败、数据库未 ready 等信息

## 3. 排查顺序

### 第一步：看容器状态

```bash
./scripts/health_check.sh
```

重点关注：

- `db` 是否健康
- `web` 是否异常退出

### 第二步：看 web 日志

`health_check.sh` 已经会输出近期 `web` 日志。

如果想单独看，可执行：

```bash
cd ../support-demo-platform
docker compose logs --tail=80 web
```

### 第三步：确认问题是否集中在数据库连接层

如果：

- `db` healthy
- `nginx` 正常
- 但 `web` 起不来

那高概率优先看：

- 数据库用户名/密码
- 数据库连接地址
- 环境变量覆盖是否被错误注入

## 4. 故障恢复

执行：

```bash
./scripts/recover_db_auth_fail.sh
```

恢复后再执行：

```bash
./scripts/health_check.sh
```

正常恢复时，应重新看到：

- `db` healthy
- `web` running
- HTTP 返回 `200`

## 5. 结论模板

可以把这类问题总结为：

> 页面异常不一定是 Nginx 配置问题，也可能是 web 应用在启动阶段就因为数据库认证失败而无法就绪。遇到这种问题，先看容器状态，再看 web 日志，比一开始就盯着代理层更有效。
