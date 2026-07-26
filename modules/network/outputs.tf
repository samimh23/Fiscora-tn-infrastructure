output "vpc_id" {
  description = "ID of the Fiscora VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID of the public staging subnet."
  value       = aws_subnet.public.id
}

