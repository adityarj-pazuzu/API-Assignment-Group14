variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Debian 12)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Debian 12 for us-east-1, update for other regions
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "my-key"  # Replace with your actual AWS key pair name
}

variable "s3_bucket_name" {
  description = "S3 bucket for backups"
  type        = string
  default     = "heart-disease-backup-bucket-unique-name"
}
