terraform {
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

resource "aws_security_group" "heart_disease_sg" {
  name_prefix = "heart-disease-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4200
    to_port     = 4200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Prefect Orion
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # MLflow UI
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # FastAPI
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "heart_disease_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  security_groups = [aws_security_group.heart_disease_sg.name]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    apt update
    apt install -y python3 python3-venv python3-dev python3-pip python3-distutils git curl

    # Clone repo (replace with your repo URL)
    git clone https://github.com/adityarj-pazuzu/API-Assignment-Group14.git /home/ubuntu/API-Assignment-Group14
    cd /home/ubuntu/API-Assignment-Group14

    # Create venv with Python 3.11
    python3 -m venv .venv
    source .venv/bin/activate

    # Install requirements
    python3 -m pip install --upgrade pip setuptools wheel
    python3 -m pip install -r requirements.txt

    # Run pipelines
    python3 pipeline/data_pipeline.py
    python3 pipeline/ml_pipeline.py

    # Start services in background
    nohup mlflow ui --host 0.0.0.0 --port 5000 &
    nohup prefect server start --host 0.0.0.0 --port 4200 &
    nohup uvicorn api.app:app --host 0.0.0.0 --port 8000 &

  EOF

  tags = {
    Name = "Heart-Disease-Pipeline"
  }
}

resource "aws_s3_bucket" "heart_disease_backup" {
  bucket = var.s3_bucket_name
}

resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = aws_iam_role.ec2_s3_access.name
  role = aws_iam_role.ec2_s3_access.name
}
