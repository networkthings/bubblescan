#!/bin/bash
# save as /usr/local/bin/refresh-aws-credentials.sh

while true; do
  echo "Refreshing AWS credentials..."
  
  # Get IMDSv2 token
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  
  # Get role name and credentials
  ROLE_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
  CREDENTIALS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)
  
  # Extract credentials using grep and cut
  ACCESS_KEY=$(echo "$CREDENTIALS" | grep -o '"AccessKeyId" : "[^"]*"' | cut -d'"' -f4)
  SECRET_KEY=$(echo "$CREDENTIALS" | grep -o '"SecretAccessKey" : "[^"]*"' | cut -d'"' -f4)
  SESSION_TOKEN=$(echo "$CREDENTIALS" | grep -o '"Token" : "[^"]*"' | cut -d'"' -f4)
  
  # Create properties file for the connector
  cat > /tmp/aws-credentials.properties << EOF
fs.s3a.access.key=$ACCESS_KEY
fs.s3a.secret.key=$SECRET_KEY
fs.s3a.session.token=$SESSION_TOKEN
EOF

  echo "Credentials refreshed. Will refresh again in 1 hour."
  sleep 3600
done
