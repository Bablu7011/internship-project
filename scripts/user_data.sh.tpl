#!/bin/bash
set -e

# Make apt-get non-interactive
export DEBIAN_FRONTEND=noninteractive

echo "Starting user_data script..."

# --------------------------
# System update & required tools
# --------------------------
echo "Running apt-get update..."
apt-get update -y
echo "Running apt-get install..."
apt-get install -y openjdk-21-jdk awscli python3
echo "Finished apt-get install."

# --------------------------
# Create application directory
# --------------------------
echo "Creating /app directory..."
mkdir -p /app/
cd /app/
echo "Changed to /app directory."

# --------------------------
# Create the polling script
# --------------------------
echo "Creating /app/poll_s3.sh script..."
cat << 'EOF' > /app/poll_s3.sh
#!/bin/bash
set -e

# Variables passed from Terraform
JAR_BUCKET="${JAR_BUCKET}"
EC2_LOGS_BUCKET="${EC2_LOGS_BUCKET}"
APP_DIR="/app"
CURRENT_JAR_MD5=""

# Get the unique instance ID from instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "Polling service started for bucket: s3://$${JAR_BUCKET}"

while true; do
  # --- APP DEPLOYMENT LOGIC ---
  aws s3 sync s3://$${JAR_BUCKET} $${APP_DIR} --delete
  JAR_FILE=$(find $${APP_DIR} -maxdepth 1 -name "*.jar" | head -n 1)

  if [ -f "$${JAR_FILE}" ]; then
    NEW_JAR_MD5=$(md5sum "$${JAR_FILE}" | awk '{ print $1 }')

    if [ "$${NEW_JAR_MD5}" != "$${CURRENT_JAR_MD5}" ]; then
      echo "New JAR file detected. Restarting application..."
      CURRENT_JAR_MD5=$${NEW_JAR_MD5}

      if pgrep -f "java -jar" || pgrep -f "python3 -m http.server 80"; then
        pkill -f "java -jar" || true
        pkill -f "python3 -m http.server 80" || true
        echo "Killed old process on port 80."
        sleep 5
      fi

      nohup java -jar "$${JAR_FILE}" --server.port=80 > /app/app.log 2>&1 &
      echo "Started new application from $${JAR_FILE}."
    fi
  fi

  # --- LOG UPLOAD LOGIC ---
  if [ -f "/app/app.log" ]; then
    aws s3 cp /app/app.log s3://$${EC2_LOGS_BUCKET}/$${INSTANCE_ID}/app.log
  fi
  if [ -f "/app/polling_service.log" ]; then
    aws s3 cp /app/polling_service.log s3://$${EC2_LOGS_BUCKET}/$${INSTANCE_ID}/polling_service.log
  fi
  
  sleep 300
done
EOF
echo "Finished creating /app/poll_s3.sh."

# --------------------------
# Start Placeholder Web Server
# --------------------------
echo "Creating a placeholder index.html for health checks..."
# ADD THIS LINE to create the file the health check looks for
echo "<h1>Health Check OK</h1>" > /app/index.html

echo "Starting placeholder web server with Python..."
nohup python3 -m http.server 80 > /app/placeholder.log 2>&1 &
echo "Placeholder Python web server is running in the background."

# --------------------------
# Run the polling script
# --------------------------
echo "Making polling script executable..."
chmod +x /app/poll_s3.sh
echo "Starting polling script in the background..."
nohup /app/poll_s3.sh > /app/polling_service.log 2>&1 &
echo "Polling script is running in the background."

echo "User_data script finished."