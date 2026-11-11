#!/usr/bin/env bash
# WSL2 Arch 下的 PostgreSQL 初始化脚本（幂等，可重复执行）
# 作用：允许 Windows 侧通过 127.0.0.1 访问，并创建 study 用户与数据库
set -euo pipefail

PGDATA=/var/lib/postgres/data
PG_CONF="$PGDATA/postgresql.conf"
PG_HBA="$PGDATA/pg_hba.conf"

# 1) 监听所有地址：WSL2 的 localhost 转发来自虚拟网卡，不能只绑 127.0.0.1
if ! grep -qE "^listen_addresses[[:space:]]*=[[:space:]]*'\*'" "$PG_CONF"; then
  echo "listen_addresses = '*'" >> "$PG_CONF"
  echo "[pg] listen_addresses -> *"
else
  echo "[pg] listen_addresses already set"
fi

# 2) 允许 WSL 虚拟网段用密码登录（scram-sha-256）
if ! grep -qE "^host[[:space:]]+all[[:space:]]+all[[:space:]]+0\.0\.0\.0/0" "$PG_HBA"; then
  echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PG_HBA"
  echo "[pg] pg_hba -> allow 0.0.0.0/0"
else
  echo "[pg] pg_hba already set"
fi

# 3) 启动并设为开机自启（WSL 的 systemd 已开启）
systemctl enable --now postgresql
sleep 2
systemctl is-active postgresql

# 4) 创建业务角色与数据库（已存在则跳过）
runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='study'" | grep -q 1 \
  || runuser -u postgres -- psql -c "CREATE ROLE study LOGIN PASSWORD 'study_dev_password' CREATEDB;"

runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='study'" | grep -q 1 \
  || runuser -u postgres -- psql -c "CREATE DATABASE study OWNER study;"

# 5) 验证：从 WSL 内部走 TCP 登录一次
PGPASSWORD=study_dev_password psql -h 127.0.0.1 -U study -d study -c "select current_database(), current_user, version();" | head -5
