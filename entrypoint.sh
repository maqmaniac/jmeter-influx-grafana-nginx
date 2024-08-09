#!/bin/sh

# Start InfluxDB in the background
influxd --config /etc/influxdb/influxdb.conf &

# Wait for InfluxDB to be ready
until nc -z localhost 8086; do
  echo "Waiting for InfluxDB..."
  sleep 1
done

# Run the init script for InfluxDB
/init-influxdb.sh

# Start Grafana
grafana-server -config /etc/grafana/grafana.ini --homepath=/usr/share/grafana &

# Start NGINX
nginx -g "daemon off;"

# Keep the container running
tail -f /dev/null