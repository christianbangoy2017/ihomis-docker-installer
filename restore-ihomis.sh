#!/bin/bash
set -e

echo "======================================"
echo " iHOMIS Plus – Docker Install & Restore"
echo "======================================"

# =========================
# CONFIG
# =========================
BASE_DIR="/opt/ihomis"
IMAGE="christianbangoy2017/ihomis-app:php7.4"

DB_NAME="hospital_dbo"
MYSQL_ROOT_PASSWORD="r00t"

APP_ZIP="ihomis-plus.zip"
APP_DIR="$BASE_DIR/app/ihomis-plus"

DB_ZIP="hospital_dbo.zip"
SEED_SQL="/tmp/hospital_dbo.sql"

SSL_DIR="$BASE_DIR/ssl"
SSL_KEY="$SSL_DIR/ihomis.key"
SSL_CRT="$SSL_DIR/ihomis.crt"

# =========================
# CHECKS
# =========================
command -v docker >/dev/null 2>&1 || {
  echo "❌ Docker is not installed. Aborting."
  exit 1
}

command -v docker compose >/dev/null 2>&1 || {
  echo "❌ docker compose plugin not found. Aborting."
  exit 1
}

for f in "$APP_ZIP" "$DB_ZIP" docker-compose.yml; do
  if [ ! -f "$f" ]; then
    echo "❌ Required file '$f' not found. Aborting."
    exit 1
  fi
done

# =========================
# PREPARE DIRECTORIES
# =========================
echo "[1/7] Creating directory structure..."
mkdir -p "$BASE_DIR/app/php" \
         "$BASE_DIR/app/bootstrap" \
         "$BASE_DIR/db/data" \
         "$SSL_DIR"

# =========================
# SSL SETUP
# =========================
echo "[SSL] Checking SSL certificates..."

if [ ! -f "$SSL_KEY" ] || [ ! -f "$SSL_CRT" ]; then
  echo "[SSL] Generating self-signed certificate..."

  openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "$SSL_KEY" \
    -out "$SSL_CRT" \
    -subj "/C=PH/ST=Davao/L=Davao/O=Hospital/OU=IT/CN=$(hostname -I | awk '{print $1}')"

  chmod 600 "$SSL_KEY"
  chmod 644 "$SSL_CRT"

  echo "[SSL] SSL generated."
else
  echo "[SSL] Existing SSL found. Skipping."
fi

# =========================
# EXTRACT WEB APPLICATION
# =========================
echo "[2/7] Preparing ihomis-plus application..."

if [ ! -d "$APP_DIR" ]; then
  echo "  → Extracting ihomis-plus.zip"
  unzip -q "$APP_ZIP" -d "$BASE_DIR/app"
else
  echo "  → ihomis-plus already exists. Skipping extraction."
fi

# =========================
# COPY OPTIONAL CONFIG FILES
# =========================
echo "[3/7] Copying optional configuration files..."

if [ -d "php" ] && [ "$(ls -A php 2>/dev/null)" ]; then
  cp -r php/* "$BASE_DIR/app/php/"
else
  echo "  ⚠️  php folder not present – skipping"
fi

if [ -d "bootstrap" ] && [ "$(ls -A bootstrap 2>/dev/null)" ]; then
  cp -r bootstrap/* "$BASE_DIR/app/bootstrap/"
else
  echo "  ⚠️  bootstrap folder not present – skipping"
fi

# =========================
# DOCKER COMPOSE
# =========================
echo "[4/7] Deploying Docker containers..."
cp docker-compose.yml "$BASE_DIR/"
cd "$BASE_DIR"

docker pull "$IMAGE"
docker compose up -d

# =========================
# WAIT FOR MYSQL
# =========================
echo "[5/7] Waiting for MySQL to be ready..."

until sudo docker exec -it ihomis-db \
  mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
  sleep 5
done

# =========================
# ADD FOLDER PERMISSONS
# =========================
echo "[6/7] Adding Folder Permissions..."



sudo docker exec -it ihomis-app mkdir -p /var/www/html/application/ci_sessions
sudo docker exec -it ihomis-app chown -R www-data:www-data /var/www/html/application/ci_sessions
sudo docker exec -it ihomis-app chmod 755 /var/www/html/application/ci_sessions


sudo docker exec ihomis-app mkdir -p /var/www/html/upload
sudo docker exec ihomis-app chown -R www-data:www-data /var/www/html/upload
sudo docker exec ihomis-app chmod -R 775 /var/www/html/upload


echo "[6.5] Enabling TCPDF Support (Installing GD & Image Libraries)..."

# Install necessary libraries for PDF generation (GD, FreeType, JPEG support)
sudo docker exec -u root ihomis-app apt-get update
sudo docker exec -u root ihomis-app apt-get install -y libpng-dev libjpeg-dev libfreetype6-dev
sudo docker exec -u root ihomis-app docker-php-ext-configure gd --with-freetype --with-jpeg
sudo docker exec -u root ihomis-app docker-php-ext-install gd

# Restart the app container to apply PHP changes
sudo docker restart ihomis-app



# =========================
# RESTORE DATABASE
# =========================
echo "[7/7] Restoring database..."

unzip -p "$OLDPWD/$DB_ZIP" > "$SEED_SQL"

sudo docker exec -it ihomis-db mysql \
  -uroot -p"$MYSQL_ROOT_PASSWORD" \
  --skip-definer "$DB_NAME" < "$SEED_SQL"

rm -f "$SEED_SQL"





# =========================
# DONE
# =========================
echo "======================================"
echo " ✅ iHOMIS Plus installed successfully"
echo "======================================"
echo "Access the system at:"
echo "https://<SERVER-IP>:8443"

