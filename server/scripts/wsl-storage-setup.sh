#!/usr/bin/env bash
# WSL2 Arch 下的对象存储初始化：安装 SeaweedFS 的 systemd 服务
# 端口与凭证与 server/.env 保持一致（9000 / study_minio / study_minio_secret）
set -euo pipefail

SRC_DIR=/mnt/d/codehub/study/server/scripts

# 1) 数据目录与配置目录
mkdir -p /var/lib/seaweedfs /etc/seaweedfs

# 2) 安装 S3 凭证配置与服务单元
install -m 0644 "$SRC_DIR/seaweedfs-s3.json" /etc/seaweedfs/s3.json
install -m 0644 "$SRC_DIR/seaweedfs.service" /etc/systemd/system/seaweedfs.service

# 3) 启动并设为开机自启
systemctl daemon-reload
systemctl enable --now seaweedfs

# 4) 等待 S3 端口就绪后验证
for i in $(seq 1 20); do
  if curl -s -o /dev/null --max-time 2 http://127.0.0.1:9000/minio/health/live || \
     curl -s -o /dev/null --max-time 2 http://127.0.0.1:9000; then
    echo "[s3] port 9000 ready after ${i}s"
    break
  fi
  sleep 1
done

systemctl is-active seaweedfs
curl -s -o /dev/null -w "s3_http=%{http_code}\n" --max-time 5 http://127.0.0.1:9000/
