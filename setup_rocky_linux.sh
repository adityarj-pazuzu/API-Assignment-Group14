#!/bin/bash

##############################################################################
# Heart Disease ML Pipeline - Rocky Linux Setup & Execution Script
#
# This script automates the complete deployment on Rocky Linux 8/9
# Usage: bash setup_rocky_linux.sh [--help]
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/opt/heart-disease-ml"
REPO_URL="${REPO_URL:-https://github.com/adityarj-pazuzu/API-Assignment-Group14.git}"
CURRENT_USER=$(whoami)
SCRIPT_VERSION="1.0"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root_or_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

show_help() {
    cat <<EOF
${BLUE}Heart Disease ML Pipeline - Rocky Linux Setup Script${NC}

Usage: sudo bash setup_rocky_linux.sh [OPTIONS]

OPTIONS:
    --help              Show this help message
    --repo-url URL      Custom GitHub repository URL (default: official repo)
    --skip-models       Skip ML model training (faster for testing)
    --skip-data         Skip initial data pipeline run
    --firewall-only     Only configure firewall (for already installed systems)

EXAMPLE:
    sudo bash setup_rocky_linux.sh
    sudo bash setup_rocky_linux.sh --skip-models
    sudo bash setup_rocky_linux.sh --repo-url https://github.com/yourname/fork.git

EOF
}

##############################################################################
# Step 1: Validate Environment
##############################################################################

step_validate_environment() {
    print_header "Step 1: Validating Environment"

    # Check if Rocky Linux
    if ! grep -q "Rocky" /etc/os-release 2>/dev/null; then
        print_warning "This script is optimized for Rocky Linux. You're running:"
        cat /etc/os-release | grep PRETTY_NAME
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_success "Environment validated"
}

##############################################################################
# Step 2: Update System & Install Dependencies
##############################################################################

step_install_dependencies() {
    print_header "Step 2: Installing System Dependencies"

    print_info "Updating system packages..."
    dnf update -y > /dev/null 2>&1
    print_success "System packages updated"

    print_info "Installing Python 3.11, Git, and development tools..."
    dnf install -y \
        python3.11 \
        python3.11-devel \
        python3.11-pip \
        git \
        gcc \
        make \
        openssl-devel \
        libffi-devel \
        sqlite-devel \
        > /dev/null 2>&1
    print_success "Dependencies installed"

    # Set Python 3.11 as default
    print_info "Setting Python 3.11 as default..."
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 > /dev/null 2>&1
    alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1 > /dev/null 2>&1
    print_success "Python 3.11 set as default"

    # Verify installation
    python3 --version | grep -q "3.11" && print_success "Python 3.11 verified" || print_error "Python 3.11 not found"
}

##############################################################################
# Step 3: Clone Repository & Setup Application Directory
##############################################################################

step_setup_app_directory() {
    print_header "Step 3: Setting Up Application Directory"

    if [ -d "$APP_DIR" ]; then
        print_warning "Directory $APP_DIR already exists"
        read -p "Remove and reinstall? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing directory..."
            rm -rf "$APP_DIR"
        else
            print_info "Skipping clone, using existing directory"
            return
        fi
    fi

    print_info "Creating application directory..."
    mkdir -p "$APP_DIR"
    chown "$CURRENT_USER:$CURRENT_USER" "$APP_DIR"
    print_success "Directory created: $APP_DIR"

    print_info "Cloning repository..."
    cd "$APP_DIR"
    sudo -u "$CURRENT_USER" git clone "$REPO_URL" . > /dev/null 2>&1
    print_success "Repository cloned"
}

##############################################################################
# Step 4: Setup Python Virtual Environment
##############################################################################

step_setup_venv() {
    print_header "Step 4: Setting Up Python Virtual Environment"

    print_info "Creating virtual environment..."
    cd "$APP_DIR"
    sudo -u "$CURRENT_USER" python3 -m venv venv > /dev/null 2>&1
    print_success "Virtual environment created"

    print_info "Installing Python dependencies..."
    sudo -u "$CURRENT_USER" bash -c 'source venv/bin/activate && \
        pip install --upgrade pip setuptools wheel > /dev/null 2>&1 && \
        pip install -r requirements.txt > /dev/null 2>&1'
    print_success "Python dependencies installed"
}

##############################################################################
# Step 5: Train ML Models
##############################################################################

step_train_models() {
    if [ "$SKIP_MODELS" = true ]; then
        print_header "Step 5: Skipping ML Model Training (--skip-models)"
        print_info "Models will not be trained. You can train later with:"
        print_info "  cd $APP_DIR && source venv/bin/activate && python3 pipeline/ml_pipeline.py"
        return
    fi

    print_header "Step 5: Training ML Models"

    print_info "Training Logistic Regression and Random Forest models..."
    print_info "This may take 2-5 minutes..."

    cd "$APP_DIR"
    if sudo -u "$CURRENT_USER" bash -c 'source venv/bin/activate && python3 pipeline/ml_pipeline.py' > /tmp/ml_train.log 2>&1; then
        print_success "ML models trained successfully"
        grep "Best model:" /tmp/ml_train.log || true
    else
        print_error "ML model training failed"
        print_info "Check logs with: cat /tmp/ml_train.log"
        return 1
    fi
}

##############################################################################
# Step 6: Run Data Pipeline
##############################################################################

step_run_data_pipeline() {
    if [ "$SKIP_DATA" = true ]; then
        print_header "Step 6: Skipping Initial Data Pipeline Run (--skip-data)"
        print_info "Data pipeline will run on schedule. Start manually with:"
        print_info "  cd $APP_DIR && source venv/bin/activate && python3 pipeline/data_pipeline.py"
        return
    fi

    print_header "Step 6: Running Initial Data Pipeline"

    print_info "Running data ingestion, preprocessing, and EDA..."
    print_info "This may take 1-3 minutes..."

    cd "$APP_DIR"
    if sudo -u "$CURRENT_USER" bash -c 'source venv/bin/activate && python3 pipeline/data_pipeline.py' > /tmp/data_pipeline.log 2>&1; then
        print_success "Data pipeline completed successfully"
    else
        print_error "Data pipeline failed"
        print_info "Check logs with: cat /tmp/data_pipeline.log"
        return 1
    fi
}

##############################################################################
# Step 7: Create Systemd Service Files
##############################################################################

step_create_systemd_services() {
    print_header "Step 7: Creating Systemd Service Files"

    # Prefect Server Service
    print_info "Creating Prefect server service..."
    tee /etc/systemd/system/prefect-server.service > /dev/null <<EOF
[Unit]
Description=Prefect Orchestration Server
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=$APP_DIR/venv/bin/prefect server start --host 0.0.0.0 --port 4200
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "Prefect server service created"

    # Data Pipeline Service
    print_info "Creating data pipeline service..."
    tee /etc/systemd/system/data-pipeline.service > /dev/null <<EOF
[Unit]
Description=Heart Disease Data Pipeline (3-minute schedule)
After=prefect-server.service
Requires=prefect-server.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="PREFECT_API_URL=http://127.0.0.1:4200/api"
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/pipeline/data_pipeline.py --serve
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "Data pipeline service created"

    # MLflow Service
    print_info "Creating MLflow UI service..."
    tee /etc/systemd/system/mlflow-ui.service > /dev/null <<EOF
[Unit]
Description=MLflow UI
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=$APP_DIR/venv/bin/mlflow ui --host 0.0.0.0 --port 5000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "MLflow UI service created"
}

##############################################################################
# Step 8: Start Services
##############################################################################

step_start_services() {
    print_header "Step 8: Starting Services"

    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"

    print_info "Enabling services for autostart..."
    systemctl enable prefect-server.service data-pipeline.service mlflow-ui.service > /dev/null 2>&1
    print_success "Services enabled for autostart"

    print_info "Starting Prefect server..."
    systemctl start prefect-server.service
    sleep 5
    if systemctl is-active --quiet prefect-server.service; then
        print_success "Prefect server started (port 4200)"
    else
        print_error "Prefect server failed to start"
        systemctl status prefect-server.service
        return 1
    fi

    print_info "Starting data pipeline service..."
    systemctl start data-pipeline.service
    sleep 3
    if systemctl is-active --quiet data-pipeline.service; then
        print_success "Data pipeline service started (3-minute schedule)"
    else
        print_error "Data pipeline service failed to start"
        systemctl status data-pipeline.service
        return 1
    fi

    print_info "Starting MLflow UI..."
    systemctl start mlflow-ui.service
    sleep 3
    if systemctl is-active --quiet mlflow-ui.service; then
        print_success "MLflow UI started (port 5000)"
    else
        print_error "MLflow UI failed to start"
        systemctl status mlflow-ui.service
        return 1
    fi
}

##############################################################################
# Step 9: Configure Firewall
##############################################################################

step_configure_firewall() {
    print_header "Step 9: Configuring Firewall"

    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        print_info "Firewalld is running. Adding port rules..."
        firewall-cmd --permanent --add-port=4200/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=5000/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        print_success "Firewall rules configured (ports 4200, 5000 open)"
    else
        print_warning "Firewalld not running. Manual firewall configuration may be needed."
        print_info "To enable: sudo systemctl start firewalld"
        print_info "To add ports: sudo firewall-cmd --permanent --add-port=4200/tcp"
    fi
}

##############################################################################
# Step 10: Verify Installation
##############################################################################

step_verify_installation() {
    print_header "Step 10: Verifying Installation"

    print_info "Checking service status..."
    echo ""

    # Check services
    for service in prefect-server data-pipeline mlflow-ui; do
        if systemctl is-active --quiet "$service.service"; then
            print_success "✓ $service is running"
        else
            print_error "✗ $service is NOT running"
        fi
    done

    echo ""
    print_info "Checking open ports..."
    echo ""

    for port in 4200 5000; do
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            print_success "✓ Port $port is listening"
        else
            print_warning "⚠ Port $port is NOT listening (service may still be starting)"
        fi
    done
}

##############################################################################
# Final Summary
##############################################################################

print_summary() {
    print_header "Installation Complete!"

    echo -e "${GREEN}Heart Disease ML Pipeline is now running on Rocky Linux${NC}\n"

    echo -e "${BLUE}Access your dashboards:${NC}"
    echo "  • Prefect Dashboard: http://<your-ip>:4200"
    echo "  • MLflow UI:         http://<your-ip>:5000"
    echo ""

    echo -e "${BLUE}Application Details:${NC}"
    echo "  • Install path:      $APP_DIR"
    echo "  • Services:          prefect-server, data-pipeline, mlflow-ui"
    echo "  • Schedule:          Data pipeline runs every 3 minutes"
    echo ""

    echo -e "${BLUE}Retrieve application details:${NC}"
    echo "  cd $APP_DIR && source venv/bin/activate"
    echo "  PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py"
    echo ""

    echo -e "${BLUE}View logs:${NC}"
    echo "  • Prefect:   sudo journalctl -u prefect-server.service -f"
    echo "  • Pipeline:  sudo journalctl -u data-pipeline.service -f"
    echo "  • MLflow:    sudo journalctl -u mlflow-ui.service -f"
    echo ""

    echo -e "${BLUE}Manage services:${NC}"
    echo "  • Stop all:     sudo systemctl stop prefect-server.service data-pipeline.service mlflow-ui.service"
    echo "  • Start all:    sudo systemctl start prefect-server.service data-pipeline.service mlflow-ui.service"
    echo "  • Restart one:  sudo systemctl restart prefect-server.service"
    echo ""

    echo -e "${BLUE}For more information:${NC}"
    echo "  See: $APP_DIR/ROCKY_LINUX_DEPLOYMENT.md"
    echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
    # Default options
    SKIP_MODELS=false
    SKIP_DATA=false
    FIREWALL_ONLY=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --repo-url)
                REPO_URL="$2"
                shift 2
                ;;
            --skip-models)
                SKIP_MODELS=true
                shift
                ;;
            --skip-data)
                SKIP_DATA=true
                shift
                ;;
            --firewall-only)
                FIREWALL_ONLY=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check for root/sudo
    check_root_or_sudo

    print_header "Heart Disease ML Pipeline - Rocky Linux Setup v$SCRIPT_VERSION"

    # Conditional execution
    if [ "$FIREWALL_ONLY" = true ]; then
        print_info "Firewall-only mode: skipping installation steps"
        step_configure_firewall
        print_summary
        exit 0
    fi

    # Full installation
    step_validate_environment
    step_install_dependencies
    step_setup_app_directory
    step_setup_venv
    step_train_models || true
    step_run_data_pipeline || true
    step_create_systemd_services
    step_start_services
    step_configure_firewall
    step_verify_installation
    print_summary
}

# Run main function
main "$@"

