#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    NODE_EXPORTER_ARCH="linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    NODE_EXPORTER_ARCH="linux-arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

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



# Get the latest version of Node Exporter
LATEST_NODE_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | jq -r .tag_name)
if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve the latest version of Node Exporter."
    exit 1
fi

echo "Latest Node Exporter version: ${LATEST_NODE_EXPORTER_VERSION}"

# Correcting the download URL format
# Notice the corrected file name construction here
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/${LATEST_NODE_EXPORTER_VERSION}/node_exporter-${LATEST_NODE_EXPORTER_VERSION:1}.${NODE_EXPORTER_ARCH}.tar.gz"
echo "Download URL: ${DOWNLOAD_URL}"

# Download and install Node Exporter
echo "Downloading Node Exporter version ${LATEST_NODE_EXPORTER_VERSION} for ${ARCH}..."
wget -q $DOWNLOAD_URL -O /tmp/node_exporter.tar.gz

# Check if the download was successful
if [[ $? -ne 0 ]]; then
    echo "Failed to download Node Exporter from ${DOWNLOAD_URL}."
    exit 1
fi

# Verify if the downloaded file is a valid tar.gz file
if ! tar -tzf /tmp/node_exporter.tar.gz &>/dev/null; then
    echo "Downloaded file is not a valid tar archive. Please check the URL and network."
    exit 1
fi

tar -xf /tmp/node_exporter.tar.gz -C /tmp
if [[ $? -ne 0 ]]; then
    echo "Failed to extract Node Exporter archive."
    exit 1
fi

sudo mv /tmp/node_exporter-${LATEST_NODE_EXPORTER_VERSION:1}.${NODE_EXPORTER_ARCH}/node_exporter /usr/local/bin/
if [[ $? -ne 0 ]]; then
    echo "Failed to move Node Exporter to /usr/local/bin."
    exit 1
fi

rm -rf /tmp/node_exporter*

# Create a dedicated user for Node Exporter
echo "Creating node_exporter user..."
sudo useradd -rs /bin/false node_exporter

# Create a systemd service file for Node Exporter
echo "Creating systemd service file..."
cat << EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address="127.0.0.1:9100"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Node Exporter service
echo "Starting Node Exporter service..."
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Confirm Node Exporter is running
if sudo systemctl status node_exporter | grep -q "active (running)"; then
    echo "Node Exporter installed and running on port 9100."
else
    echo "There was an issue starting Node Exporter. Please check the service logs."
    sudo journalctl -u node_exporter.service --no-pager
fi