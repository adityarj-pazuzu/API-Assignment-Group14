variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro is free-tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH access"
  type        = string
  # Replace with your actual key pair name before running terraform apply
  default = "my-key"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.10/32) - restricts dashboard access to your machine"
  type        = string
  # Run: curl -s https://checkip.amazonaws.com && echo "/32" to find your IP
  default = "0.0.0.0/0"
}

variable "repo_url" {
  description = "HTTPS URL of the GitHub repository to clone on the EC2 instance"
  type        = string
  default     = "https://github.com/adityarj-pazuzu/API-Assignment-Group14.git"
}

