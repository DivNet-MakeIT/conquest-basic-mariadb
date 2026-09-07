#!/bin/bash
set -e

: "${MYSQL_HOST:=127.0.0.1}"
: "${MYSQL_PORT:=3306}"
: "${HTTP_PORT:=8080}"
: "${CONQUEST_PORT:=4006}"
: "${CONQUEST_AET:=CONQUESTSRV1}"
: "${DICOM_DATA_PATH:=/data/dicom}"
: "${CONQUEST_REPO:=https://github.com/marcelvanherk/Conquest-DICOM-Server.git}"
: "${CONQUEST_MAKLINUX_OPTION:=1}"
: "${CONQUEST_INSTALL_AS_SERVICE:=n}"
: "${CONQUEST_REGENERATE_DATABASE:=y}"
: "${CONQUEST_LOCAL_IP:=127.0.0.1}"
: "${CONQUEST_LOCAL_COMPRESSION:=un}"
export MYSQL_HOST MYSQL_PORT CONQUEST_PORT CONQUEST_AET DICOM_DATA_PATH
export CONQUEST_LOCAL_IP CONQUEST_LOCAL_COMPRESSION

mkdir -p /opt/conquest "${DICOM_DATA_PATH}" /var/www/html

echo "Waiting for MariaDB at ${MYSQL_HOST}:${MYSQL_PORT} ..."
until mariadb-admin ping -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
  sleep 2
done
echo "MariaDB is up."

if [ ! -x /opt/conquest/dgate ]; then
  echo "First run - fetching and building Conquest from ${CONQUEST_REPO} ..."
  rm -rf /tmp/conquest
  git clone --depth 1 "${CONQUEST_REPO}" /tmp/conquest
  mv /tmp/conquest/* /opt/conquest/
  cd /opt/conquest
  chmod +x maklinux || true

  echo "Compiling ..."
  printf "%s\n%s\n%s\n" "${CONQUEST_MAKLINUX_OPTION}" n "${CONQUEST_INSTALL_AS_SERVICE}" \
    | ./maklinux || true

  echo "Generating dicom.ini ..."
  [ -f /opt/conquest/dicom.ini ] && mv /opt/conquest/dicom.ini /opt/conquest/dicom.ini.bak
  envsubst < /templates/dicom.ini.template > /opt/conquest/dicom.ini

  echo "Generating acrnema.map ..."
  [ -f /opt/conquest/acrnema.map ] && mv /opt/conquest/acrnema.map /opt/conquest/acrnema.map.bak
  envsubst < /templates/acrnema.map.template > /opt/conquest/acrnema.map

  mv /opt/conquest/data/* "${DICOM_DATA_PATH}" 2>/dev/null || true

  if [ "${CONQUEST_REGENERATE_DATABASE}" = "y" ]; then
    echo "Regenerating the database ..."
    gosu www-data:www-data ./dgate -v -r
  fi
else
  echo "Conquest already built (dgate present) - skipping the build."
fi

chown -R www-data:www-data "${DICOM_DATA_PATH}" /opt/conquest 2>/dev/null || true

echo "Configuring Apache on port ${HTTP_PORT} ..."
echo "Listen ${HTTP_PORT}" > /etc/apache2/ports.conf
cat > /etc/apache2/sites-available/conquest.conf <<APACHEEOF
<VirtualHost *:${HTTP_PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    DirectoryIndex index.php index.html

    <Directory /var/www/html>
        Options +ExecCGI +FollowSymLinks
        AllowOverride All
        Require all granted
        AddHandler cgi-script .exe
    </Directory>

    <Directory /var/www/html/api/dicom>
        Options +ExecCGI
        AddHandler cgi-script servertask
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/conquest-error.log
    CustomLog \${APACHE_LOG_DIR}/conquest-access.log combined
</VirtualHost>
APACHEEOF

a2dissite 000-default >/dev/null 2>&1 || true
a2ensite conquest >/dev/null 2>&1 || true

echo "Starting Apache ..."
apachectl start

echo "Starting Conquest (AE title ${CONQUEST_AET}, DICOM port ${CONQUEST_PORT}) ..."
cd /opt/conquest
if [ -x ./dgate ]; then
  # -^ names the log file; the listening port comes from TCPPort in dicom.ini
  exec gosu www-data:www-data ./dgate -v -^dgate.log
else
  echo "ERROR: dgate not found in /opt/conquest"
  ls -la /opt/conquest
  exit 1
fi
