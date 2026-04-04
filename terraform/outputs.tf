output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.heart_disease_ec2.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.heart_disease_ec2.public_ip
}

output "prefect_dashboard_url" {
  description = "Prefect orchestration dashboard"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:4200"
}

output "mlflow_ui_url" {
  description = "MLflow model tracking UI"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:5000"
}

output "fastapi_url" {
  description = "FastAPI prediction service"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:8000"
}

output "fastapi_docs_url" {
  description = "FastAPI interactive Swagger docs"
  value       = "http://${aws_instance.heart_disease_ec2.public_ip}:8000/docs"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.heart_disease_ec2.public_ip}"
}

