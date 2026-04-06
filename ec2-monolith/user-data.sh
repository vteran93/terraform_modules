#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

# ── Mount persistent EBS data volume ────────────────────────────────────────

DATA_DEVICE="${data_device}"
DATA_MOUNT="/data"

# Graviton/Nitro exposes NVMe devices — resolve the symlink
for i in $(seq 1 30); do
  [ -b "$DATA_DEVICE" ] && break
  echo "Waiting for $DATA_DEVICE ... ($i/30)"
  sleep 2
done

if ! [ -b "$DATA_DEVICE" ]; then
  echo "ERROR: $DATA_DEVICE not found after 60s" >&2
  exit 1
fi

if ! blkid "$DATA_DEVICE"; then
  mkfs.ext4 -L gg-data "$DATA_DEVICE"
fi

mkdir -p "$DATA_MOUNT"
mount "$DATA_DEVICE" "$DATA_MOUNT"

if ! grep -q "$DATA_DEVICE" /etc/fstab; then
  echo "$DATA_DEVICE $DATA_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mkdir -p "$DATA_MOUNT/docker"

# ── Install Docker with data-root on EBS ────────────────────────────────────

dnf update -y
dnf install -y docker jq

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "$DATA_MOUNT/docker"
}
EOF

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

mkdir -p /opt/${app_name}

aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_registry}

cat > /opt/${app_name}/docker-compose.yml <<'COMPOSE'
${docker_compose_content}
COMPOSE

curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker pull ${ecr_url}:${image_tag}

cd /opt/${app_name}
/usr/local/bin/docker-compose up -d

cat > /etc/systemd/system/${app_name}.service <<UNIT
[Unit]
Description=${app_name} application stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/${app_name}
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable ${app_name}.service

echo "user-data completed at $(date)"
