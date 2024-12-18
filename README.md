# Static Website Hosting with CloudFront and S3

This Terraform module creates a static site setup using Amazon S3 and CloudFront + OAC, with support for features like custom R53 domains, SPA support, and logging.

## Features

- S3 + Block Public Access
- CloudFront + Origin Access Control (OAC)
- All bucket access is restricted to CloudFront via OAC
- Optional custom domain with ACM certificate
- SPA support
- Configurable access logging with retention policy
- Server-side encryption (AES256 or KMS)


## Notes

- SPA mode redirects 404 errors to index.html with a 200 status code
- The module automatically creates a logging bucket, if not provided
- Wildcard certificates (*.example.com) are supported for custom domains
- Custom domains use ACM certificates which must be created in us-east-1
- For ACM, you **must** configure and pass the aliased provider:

```hcl
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}
```

## Usage

### Basic Usage

```hcl
module "static_website" {
  source = "path/to/module"

  name = "my-static-site"
  
  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
```

### With Custom Domain

```hcl
module "static_website" {
  source = "path/to/module"

  name          = "my-static-site"
  custom_domain = "www.example.com"
  hosted_zone_id = "Z1234567890"
  
  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
```

### SPA with Custom Domain and KMS Encryption

```hcl
module "static_website" {
  source = "path/to/module"

  name             = "my-spa"
  custom_domain    = "app.example.com"
  hosted_zone_id   = "Z1234567890"
  enable_spa_mode  = true
  sse_algorithm    = "aws:kms"
  kms_bucket_key_id = "arn:aws:kms:region:account:key/1234abcd-12ab-34cd-56ef-1234567890ab"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name of the CloudFront distribution | string | - | yes |
| bucket_name | Name of the S3 bucket | string | "" | no |
| custom_domain | Domain name for the CloudFront distribution | string | "" | no |
| hosted_zone_id | Route53 Hosted Zone ID | string | "" | no |
| enable_spa_mode | Enable SPA mode (404->index.html) | bool | false | no |
| sse_algorithm | Server-side encryption algorithm | string | "AES256" | no |
| kms_bucket_key_id | KMS key ID for bucket encryption | string | "" | no |
| logging_bucket | S3 bucket for access logs | string | "" | no |
| logging_prefix | Prefix for log files | string | "" | no |
| log_retention_days | Days to retain logs | number | 45 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the created S3 bucket |
| bucket_arn | ARN of the created S3 bucket |
| cloudfront_distribution_id | ID of the CloudFront distribution |
| cloudfront_domain_name | Domain name of the CloudFront distribution |
| acm_certificate_arn | ARN of the created ACM certificate (if applicable) |
| route53_record_fqdn | FQDN of the created Route53 record (if applicable) |

## Example Use Cases

### Static Website with custom domain

```hcl
module "blog" {
  source = "path/to/module"

  name          = "my-blog"
  custom_domain = "blog.example.com"
  hosted_zone_id = "Z1234567890"
  
  tags = {
    Environment = "production"
    Project     = "blog"
  }
}
```

### Single Page Application

```hcl
module "webapp" {
  source = "path/to/module"

  name             = "my-webapp"
  custom_domain    = "app.example.com"
  hosted_zone_id   = "Z1234567890"
  enable_spa_mode  = true
  
  tags = {
    Environment = "production"
    Project     = "webapp"
  }
}
```
