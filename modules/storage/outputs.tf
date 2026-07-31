output "documents_bucket_arn" {
  description = "ARN of the private accounting-document bucket."
  value       = aws_s3_bucket.documents.arn
}

output "documents_bucket_name" {
  description = "Name of the private accounting-document bucket."
  value       = aws_s3_bucket.documents.id
}

output "web_bucket_name" {
  description = "Name of the private React artifact bucket."
  value       = aws_s3_bucket.web.id
}

output "web_bucket_arn" {
  description = "ARN of the private React artifact bucket."
  value       = aws_s3_bucket.web.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used by the web deployment workflow."
  value       = aws_cloudfront_distribution.web.id
}

output "cloudfront_domain_name" {
  description = "Temporary CloudFront URL before a Fiscora domain is configured."
  value       = aws_cloudfront_distribution.web.domain_name
}
