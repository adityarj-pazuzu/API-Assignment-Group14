terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Data source: latest Ubuntu 22.04 LTS AMI published by Canonical
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------------------------------------------------------------------------
# Networking: use the default VPC and its first available subnet
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "heart_disease_sg" {
  name        = "heart-disease-ml-sg"
  description = "Heart Disease ML assignment - allows SSH, Prefect, MLflow, FastAPI"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # Prefect dashboard
  ingress {
    description = "Prefect dashboard"
    from_port   = 4200
    to_port     = 4200
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # MLflow UI
  ingress {
    description = "MLflow UI"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }



  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "heart-disease-ml-sg"
    Project = "Heart-Disease-Pipeline"
  }
}

# ---------------------------------------------------------------------------
# IAM role and instance profile (allows future S3 access if needed)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "heart-disease-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = "Heart-Disease-Pipeline"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "heart-disease-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------------------------------------------------------------------------
# EC2 instance
# User data installs all dependencies, trains the model, and starts every
# service persistently with nohup so the dashboards survive SSH disconnects.
# ---------------------------------------------------------------------------
resource "aws_instance" "heart_disease_ec2" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.heart_disease_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    # System packages
    apt-get update -y
    apt-get install -y python3 python3-venv python3-pip git

    # Clone the repository
    git clone ${var.repo_url} /opt/API-Assignment-Group14
    cd /opt/API-Assignment-Group14

    # Python virtual environment
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt

    # Train models first (synchronous — must complete before API starts)
    python3 pipeline/ml_pipeline.py

    # 1. Start Prefect server persistently
    nohup .venv/bin/prefect server start \
      --host 0.0.0.0 --port 4200 \
      > /opt/API-Assignment-Group14/prefect.log 2>&1 &

    # 2. Wait for Prefect to finish starting
    sleep 20

    # 3. Register and serve the 3-minute scheduled data pipeline
    nohup env PREFECT_API_URL=http://127.0.0.1:4200/api \
      .venv/bin/python3 pipeline/data_pipeline.py --serve \
      > /opt/API-Assignment-Group14/dataops.log 2>&1 &

    # 4. Wait for Prefect deployment to register (3-minute first run happens after 180 seconds)
    sleep 180

    echo "Bootstrap complete" >> /var/log/user-data.log
  EOF

  tags = {
    Name    = "Heart-Disease-Pipeline"
    Project = "Heart-Disease-Pipeline"
  }
}

