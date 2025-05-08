#!/bin/bash
# save as /usr/local/bin/refresh-aws-credentials.sh

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

while true; do
  echo "Refreshing AWS credentials..."
  
  # Get IMDSv2 token
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  
  # Get role name and credentials
  ROLE_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
  CREDENTIALS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)
  
  # Extract credentials using jq
  ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.AccessKeyId')
  SECRET_KEY=$(echo "$CREDENTIALS" | jq -r '.SecretAccessKey')
  SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Token')
  EXPIRATION=$(echo "$CREDENTIALS" | jq -r '.Expiration')
  
  # Create properties file for the connector
  cat > /tmp/aws-credentials.properties << EOF
fs.s3a.access.key=$ACCESS_KEY
fs.s3a.secret.key=$SECRET_KEY
fs.s3a.session.token=$SESSION_TOKEN
EOF

  # Calculate time until expiration (in seconds)
  EXPIRATION_SECONDS=$(date -d "$EXPIRATION" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRATION" +%s)
  CURRENT_SECONDS=$(date +%s)
  
  # Calculate refresh time (5 minutes before expiration)
  REFRESH_SECONDS=$((EXPIRATION_SECONDS - CURRENT_SECONDS - 300))
  
  # Ensure we don't have a negative refresh time
  if [ $REFRESH_SECONDS -lt 60 ]; then
    REFRESH_SECONDS=60
  fi
  
  echo "Credentials refreshed. Expiration: $EXPIRATION"
  echo "Will refresh again in $REFRESH_SECONDS seconds (5 minutes before expiration)"
  
  sleep $REFRESH_SECONDS
done
