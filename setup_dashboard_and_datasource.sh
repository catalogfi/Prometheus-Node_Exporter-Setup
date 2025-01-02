#!/bin/bash

# Get the Grafana URL, token, and middleware server URL from the user
read -p "Enter Grafana URL (e.g., http://localhost:3000): " grafana_url
read -p "Enter Grafana API Token: " grafana_token
read -p "Enter Middleware Server URL (e.g., http://middleware-server:5000): " middleware_url

# Ask for Datasource and Dashboard Name, use defaults if left blank
read -p "Enter the DataSource Name (default: $(hostname) prometheus stream): " data_source_name
data_source_name="${data_source_name:-$(hostname) prometheus stream}"  # Use default if empty

read -p "Enter the Dashboard Title (default: $(hostname) Instance Metrics Dashboard): " dashboard_title
dashboard_title="${dashboard_title:-$(hostname) Instance Metrics Dashboard}"  # Use default if empty

# Get system hostname and public IP address
data_source_uid="$(hostname -f | tr '.' '-' | tr '[:upper:]' '[:lower:]')"  # Convert FQDN to valid UID
public_ip=$(curl -s http://ifconfig.me)
data_source_url="http://$public_ip:9090"
dashboard_description="This dashboard monitors metrics for the $(hostname -f) instance, providing real-time insights into CPU, memory, and network usage."

# Create JSON payload
json_payload=$(cat <<EOF
{
  "data_source_name": "$data_source_name",
  "data_source_uid": "$data_source_uid",
  "data_source_url": "$data_source_url",
  "dashboard_title": "$dashboard_title",
  "dashboard_description": "$dashboard_description",
  "basic_auth_user": "admin",
  "basic_auth_password": "password",
  "grafana_url": "$grafana_url",
  "grafana_token": "$grafana_token"
}
EOF
)

# Make the POST request to the Flask app on the specified middleware server URL
response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$middleware_url/create_dashboard" \
-H "Content-Type: application/json" \
-d "$json_payload")

# Check the response status
if [ "$response" -eq 201 ]; then
    echo "Dashboard created successfully!"
elif [ "$response" -eq 500 ]; then
    echo "Failed to create dashboard. Please check the server logs."
else
    echo "Received unexpected response code: $response"
fi
