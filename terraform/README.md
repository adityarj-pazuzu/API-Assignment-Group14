# Terraform — Heart Disease ML Pipeline

This directory contains the Terraform configuration that provisions all AWS infrastructure required to run the Heart Disease Prediction Pipeline on a cloud VM. It creates an EC2 instance that automatically installs dependencies, trains models, and starts all services persistently on boot.

## What gets provisioned

| Resource | Details |
|---|---|
| EC2 instance | Ubuntu 22.04 LTS, `t2.micro` by default (free-tier eligible) |
| Security group | Inbound rules for SSH (22), Prefect (4200), MLflow (5000), FastAPI (8000) |
| IAM role + instance profile | Attached to EC2 for future SSM/S3 access |
| Ubuntu AMI | Resolved automatically from AWS SSM Parameter Store — always the latest Ubuntu 22.04 LTS |

## Services started automatically on the instance

The EC2 user data script runs on first boot and:

1. Installs Python 3, pip, and git
2. Clones the repository
3. Creates a virtual environment and installs all requirements
4. Trains the ML models (`pipeline/ml_pipeline.py`)
5. Starts the following services persistently with `nohup`:

| Service | Port | Log file |
|---|---|---|
| Prefect server (dashboard) | `4200` | `/opt/API-Assignment-Group14/prefect.log` |
| 3-minute scheduled data pipeline | — | `/opt/API-Assignment-Group14/dataops.log` |
| MLflow UI | `5000` | `/opt/API-Assignment-Group14/mlflow.log` |
| FastAPI prediction API | `8000` | `/opt/API-Assignment-Group14/api.log` |

All services survive SSH disconnects. The dashboards are accessible via the public IP immediately after bootstrap completes (allow ~5 minutes after `terraform apply`).

## Prerequisites

1. **Terraform** installed and on your PATH.
   ```bash
   terraform version
   ```
2. **AWS CLI** installed and configured with credentials that have EC2, IAM, and SSM read access.
   ```bash
   aws configure
   aws sts get-caller-identity
   ```
3. An **EC2 key pair** already created in your AWS account. You will need its name and the matching `.pem` file to SSH in.

   If you do not have one, create it in the AWS Console under EC2 → Key Pairs, or via CLI:
   ```bash
   aws ec2 create-key-pair \
     --region us-east-1 \
     --key-name my-key \
     --query 'KeyMaterial' \
     --output text > ~/.ssh/my-key.pem
   chmod 400 ~/.ssh/my-key.pem
   ```

## Configuration

All tuneable values live in `variables.tf`. The most important ones to set before applying:

| Variable | Default | What to change |
|---|---|---|
| `aws_region` | `us-east-1` | Change if you want to deploy in a different region |
| `instance_type` | `t2.micro` | Use `t3.small` or larger if the model training is slow |
| `key_name` | `my-key` | **Must match** an existing key pair name in your AWS account |
| `my_ip_cidr` | `0.0.0.0/0` | Replace with your IP (e.g. `203.0.113.10/32`) to restrict dashboard access |
| `repo_url` | GitHub URL | Update if you forked the repo |

The safest way to set values without editing the files is to create a `terraform.tfvars` file:

```hcl
key_name   = "my-actual-key-name"
my_ip_cidr = "203.0.113.10/32"
aws_region = "us-east-1"
```

Find your current public IP:
```bash
curl -s https://checkip.amazonaws.com && echo "/32"
```

## Deployment steps

### Step 1 — navigate to this directory
```bash
cd terraform
```

### Step 2 — initialise Terraform and download the AWS provider
```bash
terraform init
```

### Step 3 — preview what will be created
```bash
terraform plan
```

Review the output. You should see an EC2 instance, a security group, an IAM role, and an instance profile being created.

### Step 4 — apply and provision everything
```bash
terraform apply
```

Type `yes` when prompted. Terraform will print the outputs when complete:

```
Outputs:

instance_id           = "i-0abc123def456"
public_ip             = "54.123.45.67"
prefect_dashboard_url = "http://54.123.45.67:4200"
mlflow_ui_url         = "http://54.123.45.67:5000"
fastapi_url           = "http://54.123.45.67:8000"
fastapi_docs_url      = "http://54.123.45.67:8000/docs"
ssh_command           = "ssh -i ~/.ssh/my-key.pem ubuntu@54.123.45.67"
```

### Step 5 — wait for bootstrap to complete

The EC2 instance runs the install and startup script automatically on boot. This takes approximately **3–5 minutes** after `terraform apply` finishes.

Monitor bootstrap progress:
```bash
ssh -i ~/.ssh/my-key.pem ubuntu@<PUBLIC_IP>
tail -f /var/log/user-data.log
```

Bootstrap is complete when you see `Bootstrap complete` at the end of that log.

### Step 6 — verify services are running
```bash
ssh -i ~/.ssh/my-key.pem ubuntu@<PUBLIC_IP>
ss -tlnp | grep -E '4200|5000|8000'
```

All three ports should show as listening.

### Step 7 — open the dashboards in your browser

Use the URLs from `terraform output`:

- **Prefect dashboard**: `http://<PUBLIC_IP>:4200`
- **MLflow UI**: `http://<PUBLIC_IP>:5000`
- **FastAPI docs**: `http://<PUBLIC_IP>:8000/docs`

Wait at least one 3-minute cycle for the scheduled data pipeline to appear in the Prefect dashboard.

### Step 8 — retrieve application details via API
```bash
ssh -i ~/.ssh/my-key.pem ubuntu@<PUBLIC_IP>
cd /opt/API-Assignment-Group14
source .venv/bin/activate
PREFECT_API_URL=http://127.0.0.1:4200/api python3 api_details.py
```

### Step 9 — check service logs at any time
```bash
cd /opt/API-Assignment-Group14
tail -f prefect.log    # Prefect server
tail -f dataops.log    # 3-minute pipeline runs
tail -f mlflow.log     # MLflow UI
tail -f api.log        # FastAPI
```

## Destroy all resources when done

```bash
terraform destroy
```

Type `yes` when prompted. This removes the EC2 instance, security group, IAM role, and instance profile.

> **Note:** local `terraform.tfstate` files are not committed to the repository. Keep them safe — Terraform needs the state file to manage and destroy resources correctly.

## Troubleshooting

### Dashboards not reachable after 5 minutes
SSH in and check the bootstrap log:
```bash
cat /var/log/user-data.log
```
If you see errors, the most common causes are:
- pip install failing due to missing system packages
- `git clone` failing if the repo URL is wrong

### Service stopped after restart
SSH in and restart it manually:
```bash
cd /opt/API-Assignment-Group14
source .venv/bin/activate
nohup prefect server start --host 0.0.0.0 --port 4200 > prefect.log 2>&1 &
sleep 20
nohup env PREFECT_API_URL=http://127.0.0.1:4200/api python3 pipeline/data_pipeline.py --serve > dataops.log 2>&1 &
nohup mlflow ui --host 0.0.0.0 --port 5000 > mlflow.log 2>&1 &
nohup python3 -m uvicorn api.app:app --host 0.0.0.0 --port 8000 > api.log 2>&1 &
```

### Security group is blocking access
If you set `my_ip_cidr` to your IP and your IP changed, update `terraform.tfvars` and run:
```bash
terraform apply
```
Terraform will update only the security group rule without recreating the instance.

