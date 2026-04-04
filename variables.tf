variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2)"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Update to latest Amazon Linux 2 AMI
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "your-key-pair"  # Replace with your key pair
}

variable "s3_bucket_name" {
  description = "S3 bucket for backups"
  type        = string
  default     = "heart-disease-backup-bucket-unique-name"
}
