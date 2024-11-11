# Prometheus & Node Exporter Installation Automation

This repository provides automation scripts to install and configure **Prometheus** and **Node Exporter** on Linux-based systems. The scripts handle system architecture detection, package installations, and the automatic setup of Prometheus and Node Exporter as systemd services.

### Features:
- **Prometheus installation**: Installs the latest version of Prometheus, configures it, and sets up as a systemd service.
- **Node Exporter installation**: Installs the latest version of Node Exporter to monitor system metrics such as CPU, memory, and disk usage.
- **Automatic package installation**: Detects your system's package manager (APT, YUM, DNF) and installs the required dependencies.
- **Service setup**: Configures Prometheus and Node Exporter as services, ensuring they start on boot.
- **Architecture detection**: Supports both `x86_64` and `aarch64` architectures, ensuring compatibility across different hardware.

---

## Installation Steps

### Prerequisites

1. A Linux-based system (Ubuntu, CentOS, Fedora, etc.)
2. Sudo or root privileges for installing packages and creating system services.

---

### 1. Install Prometheus and Node Exporter

To run the scripts, download the respective installation scripts from this repository, make them executable, and run the script. The script will:
- Detect your system architecture (`x86_64` or `aarch64`).
- Install the necessary dependencies like `curl`, `jq`, `wget`, and `httpd-tools`.
- Download and install the latest versions of **Prometheus** and **Node Exporter**.

#### Prometheus Installation

Run the script to install Prometheus:

```bash
bash <(curl -s https://raw.githubusercontent.com/catalogfi/Prometheus-Node_Exporter-Setup/refs/heads/main/prometheus_setup.sh)
```

#### Node Exporter Installation

Run the script to install Node Exporter:

```bash
bash <(curl -s https://raw.githubusercontent.com/catalogfi/Prometheus-Node_Exporter-Setup/refs/heads/main/node_exporter_setup.sh)
```

---

### 2. Verify Installation

After running the installation scripts, you can verify that both Prometheus and Node Exporter are running with the following commands:

#### Check Prometheus Status

```bash
sudo systemctl status prometheus
```

#### Check Node Exporter Status

```bash
sudo systemctl status node_exporter
```

---

### 3. Access Prometheus and Node Exporter

- **Prometheus Web UI**: Once installed, you can access the Prometheus dashboard on your server's IP address on port `9090` (e.g., `http://<server-ip>:9090`).
- **Node Exporter Metrics**: Node Exporter exposes system metrics on port `9100` (e.g., `http://<server-ip>:9100/metrics`).

---
### Setting Up Grafana Dashboard and Data Source
To set up the Grafana dashboard and data source, run:
```
bash <(curl -s https://raw.githubusercontent.com/catalogfi/Prometheus-Node_Exporter-Setup/refs/heads/main/setup_dashboard_and_datasource.sh)
```


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

### Contributions

Feel free to open an issue or a pull request if you encounter any problems or have suggestions for improvements!
