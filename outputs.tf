output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Domain name of the created S3 bucket"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the created S3 bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "logging_bucket_name" {
  description = "Name of the logging bucket (if created)"
  value       = var.logging_bucket == "" ? aws_s3_bucket.logging_bucket[0].id : var.logging_bucket
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Route53 zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate (if created)"
  value       = var.custom_domain != "" ? aws_acm_certificate.this[0].arn : null
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate (if created)"
  value       = var.custom_domain != "" ? aws_acm_certificate.this[0].status : null
}

output "route53_record_name" {
  description = "The created Route53 record name (if custom domain was provided)"
  value       = var.custom_domain != "" ? aws_route53_record.cf_alias[0].name : null
}

output "route53_record_fqdn" {
  description = "The created Route53 record FQDN (if custom domain was provided)"
  value       = var.custom_domain != "" ? aws_route53_record.cf_alias[0].fqdn : null
}
