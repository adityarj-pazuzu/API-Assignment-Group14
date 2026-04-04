output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.heart_disease_ec2.public_ip
}

output "prefect_dashboard_url" {
  description = "URL for Prefect Orion dashboard"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:4200"
}

output "mlflow_ui_url" {
  description = "URL for MLflow UI"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:5000"
}

output "fastapi_url" {
  description = "URL for FastAPI prediction API"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:8000"
}

output "s3_bucket_name" {
  description = "S3 bucket for backups"
  value       = aws_s3_bucket.heart_disease_backup.bucket
}
