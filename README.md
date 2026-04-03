# Support Demo Ops Toolkit

一个围绕 `support-demo-platform` 构建的交付环境自动化与排障工具箱项目。

本项目的定位不是再做一个新的业务系统，而是围绕已有的 Flask + MySQL + Docker Compose + Nginx 演示环境，补齐实施 / 技术支持 / 初级运维场景中更常见的能力：

- 一键部署
- 一键下线
- 环境重置
- 健康检查
- 数据备份与恢复
- 故障注入与恢复
- 标准化 Runbook / SOP 文档沉淀

## 项目定位

这个项目主要用来展示以下能力：

- 能围绕现有业务系统做交付环境封装
- 能将重复操作抽象为可复用脚本
- 能设计并执行可复现的故障演练
- 能输出标准化排障文档，而不是只会临场手敲命令
- 能从“部署 -> 巡检 -> 备份 -> 恢复 -> 故障演练 -> 文档沉淀”这一整条链路来组织技术支持工作

## 关联项目

本工具箱默认服务于以下项目：

- 项目一：`support-demo-platform`

默认访问入口：

- `http://127.0.0.1:8080`

默认数据库连接：

- Host: `127.0.0.1`
- Port: `3307`
- Database: `support_demo`

## 当前已实现能力

### 1. 环境管理

- `deploy.sh`：构建并启动项目环境
- `down.sh`：关闭并移除容器
- `reset.sh`：删除数据卷并重建演示环境

### 2. 健康检查

- `health_check.sh`：检查容器状态、本机监听端口、HTTP 连通性、Nginx 配置、web 容器内部 5000 端口监听情况，以及近期日志

### 3. 数据保护

- `backup.sh`：导出 MySQL 数据到带时间戳的备份目录
- `restore.sh`：从指定备份恢复数据库

### 4. 故障演练

已实现以下 3 类可复现故障场景：

1. **数据库认证失败**
  
  - 脚本：`drill_db_auth_fail.sh` / `recover_db_auth_fail.sh`
  - 现象：web 启动失败，页面异常
2. **Nginx 上游配置错误**
  
  - 脚本：`drill_nginx_bad_upstream.sh` / `recover_nginx_bad_upstream.sh`
  - 现象：页面返回 `502`，但 web 和 db 可能仍正常运行
3. **web 容器无监听端口**
  
  - 脚本：`drill_web_no_listener.sh` / `recover_web_no_listener.sh`
  - 现象：web 容器可能显示 `Up`，但容器内 `5000` 无监听，页面异常

## 项目结构

```text
support-demo-ops-toolkit/
├─ backups/
│  └─ .gitkeep
├─ docs/
│  └─ runbooks/
│     ├─ db-auth-fail.md
│     ├─ nginx-bad-upstream.md
│     └─ web-no-listener.md
├─ logs/
│  ├─ .gitkeep
│  └─ drills/
│     └─ .gitkeep
├─ scripts/
│  ├─ backup.sh
│  ├─ deploy.sh
│  ├─ down.sh
│  ├─ drill_db_auth_fail.sh
│  ├─ drill_nginx_bad_upstream.sh
│  ├─ drill_web_no_listener.sh
│  ├─ health_check.sh
│  ├─ recover_db_auth_fail.sh
│  ├─ recover_nginx_bad_upstream.sh
│  ├─ recover_web_no_listener.sh
│  ├─ reset.sh
│  └─ restore.sh
├─ .env.example
├─ .gitignore
└─ README.md
```

## `.env` 配置示例

```bash
APP_DIR=../support-demo-platform
APP_URL=http://127.0.0.1:8080
COMPOSE_CMD="docker compose"
DB_SERVICE=db
DB_NAME=support_demo
DB_USER=root
DB_PASSWORD=123456
BACKUP_DIR=./backups
```

## 快速开始

### 1. 部署环境

```bash
./scripts/deploy.sh
```

### 2. 健康检查

```bash
./scripts/health_check.sh
```

### 3. 备份数据库

```bash
./scripts/backup.sh
```

### 4. 恢复最近一次备份

```bash
./scripts/restore.sh
```

### 5. 恢复指定备份

```bash
./scripts/restore.sh 20260403-123456
```

## 故障演练使用方式

### 数据库认证失败

```bash
./scripts/drill_db_auth_fail.sh
./scripts/health_check.sh
./scripts/recover_db_auth_fail.sh
```

### Nginx 上游配置错误

```bash
./scripts/drill_nginx_bad_upstream.sh
./scripts/health_check.sh
./scripts/recover_nginx_bad_upstream.sh
```

### web 容器无监听端口

```bash
./scripts/drill_web_no_listener.sh
./scripts/health_check.sh
./scripts/recover_web_no_listener.sh
```

## 推荐排障顺序

当页面打不开或返回 `502` 时，建议按下面顺序检查：

1. 先看 `docker compose ps`
2. 再看 `health_check.sh` 输出
3. 再看 `nginx` 与 `web` 日志
4. 再判断是：
  - 数据库连不上
  - Nginx 配错上游
  - web 容器端口未监听
5. 最后根据对应 Runbook 恢复

## Runbook 文档

- [数据库认证失败](docs/runbooks/db-auth-fail.md)
- [Nginx 上游配置错误](docs/runbooks/nginx-bad-upstream.md)
- [web 容器无监听端口](docs/runbooks/web-no-listener.md)

## 后续可扩展方向

- 增加 `shellcheck` 静态检查
- 增加统一日志收集脚本
- 增加一键导出故障包脚本
- 增加巡检结果汇总报告
- 增加定时备份能力
- 增加更多故障场景，例如配置语法错误、磁盘满、数据库端口冲突等