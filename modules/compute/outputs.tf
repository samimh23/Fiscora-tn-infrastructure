output "instance_id" {
  description = "ID used to deploy through AWS Systems Manager."
  value       = aws_instance.docker.id
}

output "public_dns" {
  description = "Temporary public hostname before DNS is configured."
  value       = aws_instance.docker.public_dns
}

output "public_ip" {
  description = "Temporary public IP of the staging Docker host."
  value       = aws_instance.docker.public_ip
}

output "security_group_id" {
  description = "Security group protecting the staging host."
  value       = aws_security_group.web.id
}

