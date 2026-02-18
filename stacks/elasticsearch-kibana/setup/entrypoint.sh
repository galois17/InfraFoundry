#!/bin/sh

echo "Waiting for Elasticsearch at $ELASTIC_URL..."

# Determine Auth Header for the Superuser
if [ "$SECURITY_ENABLED" = "true" ]; then
  AUTH_FLAG="-u elastic:$ELASTIC_PASSWORD"
  echo "🔒 Security is ENABLED. Using Basic Auth."
else
  AUTH_FLAG=""
  echo "🔓 Security is DISABLED."
fi

# Wait for connection
until curl -s $AUTH_FLAG $ELASTIC_URL > /dev/null; do
    echo "   ... waiting for ES to accept connections (sleeping 5s)"
    sleep 5
done

echo "Connected to Elasticsearch!"

# SETUP KIBANA PASSWORD 
if [ "$SECURITY_ENABLED" = "true" ]; then
    echo "Setting 'kibana_system' password..."
    
    # We use the 'elastic' superuser to set the 'kibana_system' password
    RESPONSE=$(curl -s -X POST "$ELASTIC_URL/_security/user/kibana_system/_password" \
         $AUTH_FLAG \
         -H "Content-Type: application/json" \
         -d "{\"password\": \"$KIBANA_PASSWORD\"}")

    if echo "$RESPONSE" | grep -q "^{}"; then
        echo "Password set successfully."
    else
        echo " Note: Password set response: $RESPONSE"
    fi
fi

# 3. Load Data
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $AUTH_FLAG "$ELASTIC_URL/logs-app-prod")

if [ "$HTTP_CODE" = "200" ]; then
    echo "Index 'logs-app-prod' already exists. Skipping data load."
else
    echo "Loading seed data..."
    if [ -f "/setup/data.json" ]; then
        curl -s -H "Content-Type: application/x-ndjson" \
             $AUTH_FLAG \
             -XPOST "$ELASTIC_URL/_bulk" \
             --data-binary "@/setup/data.json"
        echo -e "\n\n Data load complete!"
    fi
fi
