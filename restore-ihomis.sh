#!/bin/bash
set -e

echo "======================================"
echo " iHOMIS Plus – Docker Restore Script"
echo "======================================"

# === CONFIG ===
BASE_DIR="/opt/ihomis"
IMAGE="yourdockerhub/ihomis-app:php7.4"
DB_NAME="hospital_dbo"
DB_USER="doh"
DB_PASS="doh123456"
SQL_FILE="hospital_dbo_seed.sql"

# === CHECKS ===
command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed. Aborting."
  exit 1
}

command -v docker compose >/dev/null 2>&1 || {
  echo "docker compose plugin not found. Aborting."
  exit 1
}

if [ ! -f "$SQL_FILE" ]; then
  echo "Database dump $SQL_FILE not found. Aborting."
  exit 1
fi

# === PREPARE DIRECTORIES ===
echo "[1/7] Creating directory structure..."
sudo mkdir -p $BASE_DIR/app/{php,bootstrap}
sudo mkdir -p $BASE_DIR/ssl
sudo mkdir -p $BASE_DIR/db/data
sudo chown -R $USER:$USER $BASE_DIR

# === COPY FILES ===
echo "[2/7] Copying configuration files..."
cp -r ssl/*        $BASE_DIR/ssl/
cp -r php/*        $BASE_DIR/app/php/
cp -r bootstrap/*  $BASE_DIR/app/bootstrap/
cp docker-compose.yml $BASE_DIR/

# === PULL IMAGE ===
echo "[3/7] Pulling Docker image..."
docker pull $IMAGE

# === START CONTAINERS ===
echo "[4/7] Starting containers..."
cd $BASE_DIR
docker compose up -d

# === WAIT FOR MYSQL ===
echo "[5/7] Waiting for MySQL to initialize..."
sleep 25

# === RESTORE DATABASE ===
echo "[6/7] Restoring database..."
docker exec -i ihomis-db \
  mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} < $OLDPWD/$SQL_FILE

# === DONE ===
echo "======================================"
echo " Restore completed successfully"
echo "======================================"
echo "Access iHOMIS at:"
echo "https://<SERVER-IP>:8443"
