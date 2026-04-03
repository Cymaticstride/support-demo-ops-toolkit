# Support Demo Ops Toolkit

一个围绕 `support-demo-platform` 构建的交付环境自动化与基础巡检工具箱。

## 项目定位

本项目不负责业务页面开发，而是负责：

- 部署启动
- 环境关闭
- 演示环境重置
- 基础健康检查

目标是把 Demo 系统的常见交付动作标准化，形成更贴近技术支持 / 软件实施 / 初级运维岗位的工具层。

## 当前已实现脚本

- `scripts/deploy.sh`
- `scripts/down.sh`
- `scripts/reset.sh`
- `scripts/health_check.sh`

## 依赖前提

默认项目一目录为：

```text
../support-demo-platform
````

如果你的目录不同，请复制 `.env.example` 为 `.env` 后自行修改。

## 使用方式

### 启动项目一

```bash
./scripts/deploy.sh
```

### 关闭项目一

```bash
./scripts/down.sh
```

### 重置演示环境

```bash
./scripts/reset.sh
```

### 基础巡检

```bash
./scripts/health_check.sh
```
