#!/bin/bash
set -e

# --------------------------
# System update & required tools
# --------------------------
apt-get update -y
apt-get install -y openjdk-21-jdk awscli ncat

# --------------------------
# Create application directory
# --------------------------
mkdir -p /app/
cd /app/

# --------------------------
# Set bucket name from Terraform
# --------------------------
JAR_BUCKET="${jar_bucket_name}"   # Terraform replaces this with actual bucket name
APP_DIR="/app"
CURRENT_JAR_MD5=""

# --------------------------
# Create the polling script
# --------------------------
cat << 'EOF' > /app/poll_s3.sh
#!/bin/bash
set -e

JAR_BUCKET="${jar_bucket_name}"
APP_DIR="/app"
CURRENT_JAR_MD5=""

echo "Starting S3 polling service for bucket: s3://$${JAR_BUCKET}"

while true; do
  # Sync new/updated JARs from S3
  aws s3 sync s3://$${JAR_BUCKET} $${APP_DIR} --delete

  JAR_FILE=$(find $${APP_DIR} -maxdepth 1 -name "*.jar" | head -n 1)

  if [ -f "$${JAR_FILE}" ]; then
    NEW_JAR_MD5=$(md5sum "$${JAR_FILE}" | awk '{ print $1 }')

    if [ "$${NEW_JAR_MD5}" != "$${CURRENT_JAR_MD5}" ]; then
      echo "New JAR detected ($$(basename $${JAR_FILE})). Restarting app..."
      CURRENT_JAR_MD5=$${NEW_JAR_MD5}

      # Kill old app process if exists
      if pgrep -f "java -jar" || pgrep -f "nc -l -p 80"; then
        pkill -f "java -jar" || true
        pkill -f "nc -l -p 80" || true
        echo "Killed old process on port 80."
        sleep 5
      fi

      # Start new JAR
      nohup java -jar "$${JAR_FILE}" --server.port=80 > /app/app.log 2>&1 &
      echo "Started new app from $${JAR_FILE}."
    fi
  fi

  sleep 60
done
EOF

# --------------------------
# Start placeholder web server
# --------------------------
while true; do { echo -e 'HTTP/1.1 200 OK\r\n'; echo '<h1>Placeholder OK</h1>'; } | nc -l -p 80; done &

# --------------------------
# Run the polling script
# --------------------------
chmod +x /app/poll_s3.sh
nohup /app/poll_s3.sh > /app/polling_service.log 2>&1 &
