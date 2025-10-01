#!/bin/bash
set -e

# --------------------------
# System update & required tools
# --------------------------
apt-get update -y
apt-get install -y openjdk-21-jdk awscli

# --------------------------
# Create application directory
# --------------------------
mkdir -p /app/
cd /app/

# --------------------------
# Create the polling script
# --------------------------
cat << 'EOF' > /app/poll_s3.sh
#!/bin/bash
set -e

# Variables passed from Terraform
JAR_BUCKET="${jar_bucket_name}"
APP_DIR="/app"
CURRENT_JAR_MD5=""

echo "Starting S3 polling service for bucket: s3://\${JAR_BUCKET}"

while true; do
  # Use sync to efficiently download only new or updated files
  aws s3 sync s3://\${JAR_BUCKET} \${APP_DIR} --delete

  JAR_FILE=\$(find \${APP_DIR} -maxdepth 1 -name "*.jar" | head -n 1)

  if [ -f "\${JAR_FILE}" ]; then
    NEW_JAR_MD5=\$(md5sum "\${JAR_FILE}" | awk '{ print $1 }')

    # Check if the JAR file has changed since the last run
    if [ "\${NEW_JAR_MD5}" != "\${CURRENT_JAR_MD5}" ]; then
      echo "New JAR file detected (\$(basename \${JAR_FILE})). Restarting application..."
      CURRENT_JAR_MD5=\${NEW_JAR_MD5}

      # Find and kill the old Java process, if it exists
      if pgrep -f "java -jar"; then
        pkill -f "java -jar"
        echo "Killed old Java process."
        sleep 5
      fi

      # Start the new application in the background
      nohup java -jar "\${JAR_FILE}" --server.port=80 > /app/app.log 2>&1 &
      echo "Started new application from \${JAR_FILE}."
    fi
  fi
  # Wait for 60 seconds before checking again
  sleep 60
done
EOF

# --------------------------
# Run the polling script
# --------------------------
chmod +x /app/poll_s3.sh
nohup /app/poll_s3.sh > /app/polling_service.log 2>&1 &