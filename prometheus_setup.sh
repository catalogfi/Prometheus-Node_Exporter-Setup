#!/bin/bash

# Check and install required packages based on the detected package manager
if command -v apt-get &> /dev/null; then
    echo "Debian-based distribution detected (e.g., Ubuntu). Installing relevant packages..."
    sudo apt-get update
    sudo apt-get install -y curl jq wget apache2-utils
    echo "Packages installed successfully on Debian-based distribution."

elif command -v yum &> /dev/null; then
    echo "Red Hat-based distribution detected (e.g., CentOS/RHEL). Installing relevant packages..."
    sudo yum update -y
    sudo yum install -y curl jq wget httpd-tools
    echo "Packages installed successfully on Red Hat-based distribution."

elif command -v dnf &> /dev/null; then
    echo "Fedora-based distribution detected. Installing relevant packages..."
    sudo dnf update -y
    sudo dnf install -y curl jq wget httpd-tools
    echo "Packages installed successfully on Fedora-based distribution."

else
    echo "Unsupported package manager. Please install packages manually."
    echo "Required packages: curl, jq, wget, apache2-utils (or httpd-tools on Red Hat/Fedora systems)"
    exit 1
fi


# Get the latest version of Prometheus
LATEST_PROMETHEUS_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | jq -r .tag_name)
if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve the latest version of Prometheus."
    exit 1
fi

echo "Latest Prometheus version: ${LATEST_PROMETHEUS_VERSION}"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    PROMETHEUS_ARCH="linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    PROMETHEUS_ARCH="linux-arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Correcting the download URL format
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/${LATEST_PROMETHEUS_VERSION}/prometheus-${LATEST_PROMETHEUS_VERSION:1}.${PROMETHEUS_ARCH}.tar.gz"
echo "Download URL: ${DOWNLOAD_URL}"

# Download and install Prometheus
echo "Downloading Prometheus version ${LATEST_PROMETHEUS_VERSION} for ${ARCH}..."
wget -q $DOWNLOAD_URL -O /tmp/prometheus.tar.gz
if [[ $? -ne 0 ]]; then
    echo "Failed to download Prometheus from ${DOWNLOAD_URL}."
    exit 1
fi

# Verify if the downloaded file is a valid tar.gz file
if ! tar -tzf /tmp/prometheus.tar.gz &>/dev/null; then
    echo "Downloaded file is not a valid tar archive. Please check the URL and network."
    exit 1
fi

# Extract the files
tar -xf /tmp/prometheus.tar.gz -C /tmp
if [[ $? -ne 0 ]]; then
    echo "Failed to extract Prometheus archive."
    exit 1
fi

# Move Prometheus binaries and console files
sudo mv /tmp/prometheus-${LATEST_PROMETHEUS_VERSION:1}.${PROMETHEUS_ARCH}/prometheus /usr/local/bin/
sudo mv /tmp/prometheus-${LATEST_PROMETHEUS_VERSION:1}.${PROMETHEUS_ARCH}/promtool /usr/local/bin/
sudo mv /tmp/prometheus-${LATEST_PROMETHEUS_VERSION:1}.${PROMETHEUS_ARCH}/consoles /etc/prometheus/
sudo mv /tmp/prometheus-${LATEST_PROMETHEUS_VERSION:1}.${PROMETHEUS_ARCH}/console_libraries /etc/prometheus/
if [[ $? -ne 0 ]]; then
    echo "Failed to move Prometheus files to /usr/local/bin or /etc/prometheus."
    exit 1
fi

# Cleanup temporary files
rm -rf /tmp/prometheus*

# Create a dedicated user for Prometheus
echo "Creating prometheus user..."
if ! id prometheus &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false prometheus
    if [[ $? -ne 0 ]]; then
        echo "Failed to create prometheus user."
        exit 1
    fi
fi

# Create necessary directories
sudo mkdir -p /var/lib/prometheus
if [[ $? -ne 0 ]]; then
    echo "Failed to create /var/lib/prometheus directory."
    exit 1
fi

# Set permissions
sudo chown -R prometheus:prometheus /var/lib/prometheus /etc/prometheus
if [[ $? -ne 0 ]]; then
    echo "Failed to set permissions for Prometheus directories."
    exit 1
fi

# Generate password hash using htpasswd
if [[ -z "$ADMIN_PASSWORD" ]]; then
    echo "Environment variable ADMIN_PASSWORD not found, using default password."
    ADMIN_PASSWORD="password"
fi

# Generate the hashed password using htpasswd
PASSWORD_HASH=$(htpasswd -nbB admin "$ADMIN_PASSWORD" | cut -d ':' -f 2)
if [[ -z "$PASSWORD_HASH" ]]; then
    echo "Failed to generate password hash."
    exit 1
fi

# Create a Prometheus configuration file (exporter.yml)
echo "Creating Prometheus configuration file (exporter.yml)..."
cat << EOF | sudo tee /etc/prometheus/exporter.yml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['127.0.0.1:9100']
EOF

# Create web.yml for basic auth
echo "Creating Prometheus web configuration file (web.yml)..."
cat << EOF | sudo tee /etc/prometheus/web.yml
basic_auth_users:
    admin: ${PASSWORD_HASH}
EOF

# Create a systemd service file for Prometheus
echo "Creating systemd service file for Prometheus..."
cat << EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/exporter.yml \
  --web.config.file=/etc/prometheus/web.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Prometheus service
echo "Starting Prometheus service..."
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Confirm Prometheus is running
if sudo systemctl status prometheus | grep -q "active (running)"; then
    echo "Prometheus installed and running."
else
    echo "There was an issue starting Prometheus. Please check the service logs."
    sudo journalctl -u prometheus.service --no-pager
fi