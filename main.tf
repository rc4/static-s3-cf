locals {
  # If bucket_name is not provided, generate a unique name using a random suffix.
  bucket_name = var.bucket_name != "" ? var.bucket_name : random_id.bucket_name[0].hex
}

# Generate a random name if bucket_name is empty
resource "random_id" "bucket_name" {
  count       = var.bucket_name == "" ? 1 : 0
  byte_length = 8
  prefix      = var.name
  keepers = {
    name = var.name
  }
}

# Create the main S3 bucket with secure defaults.
resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = false

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = can(var.sse_algorithm == "aws:kms") ? var.kms_bucket_key_id : null
    }
  }
}

# Block all public access to the S3 bucket.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Allow CloudFront to access the S3 bucket via OAC
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.this.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  }
}

# Create an Origin Access Control (OAC) for CloudFront to securely access the S3 bucket.
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "oac-${var.name}"
  description                       = "CloudFront OAC policy for ${aws_s3_bucket.this.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Optionally create a logging bucket if one is not provided.
resource "aws_s3_bucket" "logging_bucket" {
  count = var.logging_bucket == "" ? 1 : 0

  # Generate a name based on the main bucket name.
  bucket        = "${aws_s3_bucket.this.id}-logs"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${aws_s3_bucket.this.id}-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logging_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = can(var.sse_algorithm == "aws:kms") ? var.kms_bucket_key_id : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logging_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count  = var.logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.logging_bucket[0].id

  rule {
    id     = "cleanup-old-logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }
  }
}

# Provision the CloudFront distribution.
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${aws_s3_bucket.this.id}"
  default_root_object = var.default_root_object
  aliases             = var.custom_domain != "" ? [var.custom_domain] : []

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.this.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  # Cache behavior with compression enabled
  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.this.id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    compress = true
  }

  # Optional SPA support - redirects 404s to index.html
  dynamic "custom_error_response" {
    for_each = var.enable_spa_mode ? [1] : []
    content {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
      error_caching_min_ttl = 300
    }
  }

  # Viewer certificate configuration. Use ACM certificate if custom_domain is set, otherwise use the default CloudFront certificate.
  # Set the minimum protocol version to TLSv1.2_2021 if an ACM certificate is in use.
  viewer_certificate {
    acm_certificate_arn            = var.custom_domain != "" ? aws_acm_certificate.this[0].arn : null
    cloudfront_default_certificate = var.custom_domain == "" ? true : false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = var.custom_domain != "" ? "TLSv1.2_2021" : null
  }

  # Enable logging using either the provided bucket or the one we created.
  logging_config {
    bucket          = var.logging_bucket != "" ? var.logging_bucket : aws_s3_bucket.logging_bucket[0].bucket_domain_name
    include_cookies = false
    prefix          = var.logging_prefix
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Ensure OAC is created before the distribution.
  depends_on = [aws_cloudfront_origin_access_control.this]
}

# Provision an ACM certificate (in us-east-1) if a custom domain is provided and no external ARN is given.
resource "aws_acm_certificate" "this" {
  provider          = aws.us-east-1
  count             = var.custom_domain != ""
  domain_name       = var.custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create a DNS validation record for the ACM certificate.
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

# Validate the ACM certificate once the DNS record is in place.
resource "aws_acm_certificate_validation" "this" {
  count                   = var.custom_domain != ""
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [aws_route53_record.acm_validation[0].fqdn]
}

# Create a Route53 alias record mapping the custom domain to the CloudFront distribution.
resource "aws_route53_record" "cf_alias" {
  count = var.custom_domain != ""

  zone_id = var.hosted_zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
