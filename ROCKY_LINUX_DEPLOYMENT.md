# Rocky Linux Deployment Guide

This guide explains how to run the Heart Disease Prediction Pipeline on a Rocky Linux instance (on-premises, VM, or cloud).

## Quick Start (Automated Setup)

The fastest way to deploy is using the automated setup script:

```bash
# Download and run the setup script (handles everything)
sudo bash setup_rocky_linux.sh

# Or with custom options:
sudo bash setup_rocky_linux.sh --skip-models           # Skip ML training for faster setup
sudo bash setup_rocky_linux.sh --repo-url YOUR_FORK    # Use your GitHub fork
```

**What the script does:**
- Installs Python 3.11, Git, and dependencies
- Clones the repository
- Creates virtual environment and installs packages
- Trains ML models
- Runs initial data pipeline
- Creates systemd service files
- Starts all services
- Configures firewall

**Result:** Fully operational system with dashboards at `http://your-ip:4200` (Prefect) and `http://your-ip:5000` (MLflow)

---

## Manual Deployment

If you prefer to deploy step-by-step, follow the instructions below.

- **Rocky Linux 8.x or 9.x** installed and accessible via SSH or local console
- **Root or sudo access** to install packages
- **Python 3.9+** (will be installed if missing)
- **Git** installed (will be installed if missing)
- **4GB RAM minimum**, 2 CPU cores recommended
- Internet access to download packages and clone the repository

## System Architecture

The deployment will run these services on a single Rocky Linux machine:

| Service | Port | Purpose |
|---|---|---|
| Prefect Server | `4200` | Orchestration dashboard + flow management |
| MLflow UI | `5000` | Model tracking and metrics visualization |
| Data Pipeline | — | Scheduled every 3 minutes via Prefect |

## Step-by-Step Deployment

### Step 1 — SSH into Rocky Linux instance

```bash
ssh user@rocky-linux-ip-address
```

### Step 2 — Update system packages

```bash
sudo dnf update -y
```

### Step 3 — Install system dependencies

```bash
sudo dnf install -y \
  python3.11 \
  python3.11-devel \
  python3.11-pip \
  git \
  gcc \
  make \
  openssl-devel \
  libffi-devel \
  sqlite-devel
```

### Step 4 — Set Python 3.11 as default (optional)

```bash
sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
sudo alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1
```

Verify:
```bash
python3 --version
pip3 --version
```

### Step 5 — Create application directory

```bash
sudo mkdir -p /opt/heart-disease-ml
sudo chown $USER:$USER /opt/heart-disease-ml
cd /opt/heart-disease-ml
```

### Step 6 — Clone the repository

```bash
git clone https://github.com/adityarj-pazuzu/API-Assignment-Group14.git .
```

Or if using your forked version:
```bash
git clone https://github.com/your-username/API-Assignment-Group14.git .
```

### Step 7 — Create Python virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
```

### Step 8 — Upgrade pip and install dependencies

```bash
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

### Step 9 — Train ML models

```bash
python3 pipeline/ml_pipeline.py
```

This trains both Logistic Regression and Random Forest models and saves metrics to `models/metrics_report.json`.

**Output:**
```
Best model: random_forest
Saved model to: /opt/heart-disease-ml/models/model.pkl
Saved metrics report to: /opt/heart-disease-ml/models/metrics_report.json
```

### Step 10 — Run data pipeline once

```bash
python3 pipeline/data_pipeline.py
```

This generates:
- `deployment/heart_processed.csv`
- `deployment/data_pipeline_report.json`
- `deployment/*.png` (charts)

### Step 11 — Start Prefect server persistently

Create a systemd service file:

```bash
sudo tee /etc/systemd/system/prefect-server.service > /dev/null <<'EOF'
[Unit]
Description=Prefect Orchestration Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/heart-disease-ml
Environment="PATH=/opt/heart-disease-ml/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/opt/heart-disease-ml/venv/bin/prefect server start --host 0.0.0.0 --port 4200
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

Replace `$USER` with your actual username (e.g., `centos`, `rocky`, etc.):

```bash
sudo sed -i "s/\$USER/$(whoami)/g" /etc/systemd/system/prefect-server.service
```

Start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable prefect-server.service
sudo systemctl start prefect-server.service
```

Verify it's running:

```bash
sudo systemctl status prefect-server.service
ss -tlnp | grep 4200
```

### Step 12 — Register and serve the data pipeline every 3 minutes

Create another systemd service:

```bash
sudo tee /etc/systemd/system/data-pipeline.service > /dev/null <<'EOF'
[Unit]
Description=Heart Disease Data Pipeline (3-minute schedule)
After=prefect-server.service
Requires=prefect-server.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/heart-disease-ml
Environment="PATH=/opt/heart-disease-ml/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="PREFECT_API_URL=http://127.0.0.1:4200/api"
ExecStart=/opt/heart-disease-ml/venv/bin/python3 /opt/heart-disease-ml/pipeline/data_pipeline.py --serve
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

Replace `$USER`:

```bash
sudo sed -i "s/\$USER/$(whoami)/g" /etc/systemd/system/data-pipeline.service
```

Start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable data-pipeline.service
sudo systemctl start data-pipeline.service
```

Verify:

```bash
sudo systemctl status data-pipeline.service
```

### Step 13 — Start MLflow UI persistently

```bash
sudo tee /etc/systemd/system/mlflow-ui.service > /dev/null <<'EOF'
[Unit]
Description=MLflow UI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/heart-disease-ml
Environment="PATH=/opt/heart-disease-ml/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/opt/heart-disease-ml/venv/bin/mlflow ui --host 0.0.0.0 --port 5000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

Replace `$USER`:

```bash
sudo sed -i "s/\$USER/$(whoami)/g" /etc/systemd/system/mlflow-ui.service
```

Start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mlflow-ui.service
sudo systemctl start mlflow-ui.service
```

Verify all services are running:

```bash
sudo systemctl status prefect-server.service data-pipeline.service mlflow-ui.service
ss -tlnp | grep -E '4200|5000'
```

### Step 14 — Configure firewall (if enabled)

If firewalld is running, allow ports 4200 and 5000:

```bash
sudo firewall-cmd --permanent --add-port=4200/tcp
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

Check:

```bash
sudo firewall-cmd --list-ports
```

### Step 15 — Access the dashboards

From your laptop, open a browser:

- **Prefect Dashboard**: `http://rocky-linux-ip:4200`
- **MLflow UI**: `http://rocky-linux-ip:5000`

Wait 3-5 minutes for the first scheduled data pipeline run to appear in Prefect.

### Step 16 — Retrieve application details via API

```bash
cd /opt/heart-disease-ml
source venv/bin/activate
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

Output will show:
```
Flow count: 1
Flows:
Flow ID: ..., Name: data-pipeline

Deployment count: 1
Deployments:
Deployment ID: ..., Name: heart-dataops-3min
```

## Monitoring and Logs

### View Prefect server logs

```bash
sudo journalctl -u prefect-server.service -f
```

### View data pipeline logs

```bash
sudo journalctl -u data-pipeline.service -f
```

### View MLflow logs

```bash
sudo journalctl -u mlflow-ui.service -f
```

### Check service status anytime

```bash
sudo systemctl status prefect-server.service data-pipeline.service mlflow-ui.service
```

## Starting and Stopping Services

### Stop all services

```bash
sudo systemctl stop prefect-server.service data-pipeline.service mlflow-ui.service
```

### Start all services

```bash
sudo systemctl start prefect-server.service data-pipeline.service mlflow-ui.service
```

### Restart a service

```bash
sudo systemctl restart prefect-server.service
```

### Disable autostart (optional)

```bash
sudo systemctl disable prefect-server.service data-pipeline.service mlflow-ui.service
```

## Troubleshooting

### Port 4200 or 5000 already in use

Find what's using it:
```bash
sudo ss -tlnp | grep :4200
sudo ss -tlnp | grep :5000
```

Kill the process:
```bash
sudo kill -9 <PID>
```

### Service fails to start

Check logs:
```bash
sudo journalctl -u prefect-server.service -n 50
```

Common issues:
- **Port permission denied**: Run with sudo or change port
- **Python not found**: Check venv activation and `pip list`
- **Module not found**: Reinstall requirements: `pip install -r requirements.txt`

### Cannot access dashboard from remote machine

Check firewall:
```bash
sudo firewall-cmd --list-ports
sudo firewall-cmd --permanent --add-port=4200/tcp
sudo firewall-cmd --reload
```

Check if service is running:
```bash
sudo systemctl status prefect-server.service
ss -tlnp | grep 4200
```

### Data pipeline not running every 3 minutes

Check deployment registration:
```bash
cd /opt/heart-disease-ml
source venv/bin/activate
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

Check data pipeline service logs:
```bash
sudo journalctl -u data-pipeline.service -f
```

## Uninstall (optional)

Remove all services:

```bash
sudo systemctl stop prefect-server.service data-pipeline.service mlflow-ui.service
sudo systemctl disable prefect-server.service data-pipeline.service mlflow-ui.service
sudo rm /etc/systemd/system/{prefect-server,data-pipeline,mlflow-ui}.service
sudo systemctl daemon-reload
rm -rf /opt/heart-disease-ml
```

## Key Files and Locations

- **Application root**: `/opt/heart-disease-ml`
- **Virtual environment**: `/opt/heart-disease-ml/venv`
- **Data artifacts**: `/opt/heart-disease-ml/deployment/`
- **Model artifacts**: `/opt/heart-disease-ml/models/`
- **Service files**: `/etc/systemd/system/`
- **Logs**: `sudo journalctl -u <service-name>`

## Environment

The services run with:
- **User**: Your current OS user (whoever runs the installation)
- **Working directory**: `/opt/heart-disease-ml`
- **Python**: `/opt/heart-disease-ml/venv/bin/python3`
- **Prefect API URL**: `http://127.0.0.1:4200/api`

---

**Deployment complete!** Your Heart Disease ML Pipeline is now running on Rocky Linux with persistent services, scheduled every 3 minutes, with full Prefect and MLflow observability.


