#!/bin/bash
set -e

echo "======================================"
echo " iHOMIS Plus – Docker Restore Script"
echo "======================================"

# === CONFIG ===
BASE_DIR="/opt/ihomis"
IMAGE="christianbangoy2017/ihomis-app:php7.4"

DB_NAME="hospital_dbo"
DB_USER="doh"
DB_PASS="doh123456"
MYSQL_ROOT_PASSWORD="r00t"

SEED_ARCHIVE="db/hospital_dbo_seed.zip"
SEED_SQL="/tmp/hospital_dbo_seed.sql"


SSL_DIR="ssl"
SSL_KEY="$SSL_DIR/ihomis.key"
SSL_CRT="$SSL_DIR/ihomis.crt"



# === CHECKS ===
command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed. Aborting."
  exit 1
}

command -v docker compose >/dev/null 2>&1 || {
  echo "docker compose plugin not found. Aborting."
  exit 1
}

if [ ! -f "$SEED_ARCHIVE" ]; then
  echo "Seed archive $SEED_ARCHIVE not found. Aborting."
  exit 1
fi

# === PREPARE DIRECTORIES ===
echo "[1/7] Creating directory structure..."
mkdir -p $BASE_DIR/app/{php,bootstrap}
mkdir -p $BASE_DIR/ssl
mkdir -p $BASE_DIR/db/data

echo "[SSL] Checking SSL certificates..."

if [ ! -f "$SSL_KEY" ] || [ ! -f "$SSL_CRT" ]; then
  echo "[SSL] SSL certificates not found. Generating self-signed certificate..."

  mkdir -p "$SSL_DIR"

  openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "$SSL_KEY" \
    -out "$SSL_CRT" \
    -subj "/C=PH/ST=Davao/L=Davao/O=Hospital/OU=IT/CN=$(hostname -I | awk '{print $1}')"

  chmod 600 "$SSL_KEY"
  chmod 644 "$SSL_CRT"

  echo "[SSL] Self-signed SSL certificate generated."
else
  echo "[SSL] Existing SSL certificates found. Skipping generation."
fi



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
sleep 30

# === EXTRACT SEED ===
echo "[6/7] Extracting seed database..."
unzip -c "$OLDPWD/$SEED_ARCHIVE" > "$SEED_SQL"

# === RESTORE DATABASE ===
echo "[7/7] Restoring database..."
docker exec -i ihomis-db mysql \
  -uroot -p"$MYSQL_ROOT_PASSWORD" \
  --skip-definer "$DB_NAME" < "$SEED_SQL"

rm -f "$SEED_SQL"

echo "======================================"
echo " Restore completed successfully"
echo "======================================"
echo "Access iHOMIS at:"
echo "https://<SERVER-IP>:8443"

