variable "name" {
  description = "Name of the CloudFront distribution. May be used to derive bucket names and other resource names."
  type        = string
  nullable    = false
}

variable "bucket_name" {
  description = "Name of the S3 bucket. If empty, a unique name is generated."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm for the S3 bucket (e.g., AES256 or aws:kms)."
  type        = string
  default     = "AES256"
  validation {
    condition     = var.sse_algorithm == "AES256" || var.sse_algorithm == "aws:kms"
    error_message = "sse_algorithm must be either 'AES256' or 'aws:kms'."
  }
}

variable "kms_bucket_key_id" {
  description = "KMS key ID of an existing key to use for bucket encryption, if sse_algorithm is set to aws:kms. Omit for S3 managed encryption."
  type        = string
  default     = ""

  validation {
    condition     = var.sse_algorithm == "aws:kms" && var.kms_bucket_key_id != ""
    error_message = "kms_bucket_key_id must be provided when sse_algorithm is 'aws:kms'."
  }
  validation {
    condition     = var.sse_algorithm != "aws:kms" && var.kms_bucket_key_id == ""
    error_message = "kms_bucket_key_id is not valid if sse_algorithm is not 'aws:kms'."
  }
}

variable "default_root_object" {
  description = "Default root object for the CloudFront distribution."
  type        = string
  default     = "index.html"
}

# Logging configuration
variable "logging_bucket" {
  description = "S3 bucket name (not ARN) for CloudFront logs. If omitted, one will be created automatically. Must be a valid S3 bucket name if provided."
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for CloudFront logs in the logging bucket (e.g., 'cloudfront/site1/'). Must not start with a slash."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain CloudFront logs. Logs older than this will be deleted."
  type        = number
  default     = 45
}

# Custom Domain
variable "custom_domain" {
  description = "Fully qualified domain name for the CloudFront distribution (e.g., www.example.com, *.example.com). Wildcards are supported for subdomains."
  type        = string
  default     = ""

  validation {
    condition     = var.custom_domain == "" || can(regex("^(\\*\\.|[a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.custom_domain))
    error_message = "custom_domain must be a valid fully qualified domain name (FQDN) or wildcard domain (e.g., www.example.com or *.example.com)."
  }
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID (e.g., Z2FDTNDATAQYW2) for the custom domain. Required when custom_domain is set."
  type        = string
  default     = ""

  validation {
    condition     = (var.custom_domain == "" && var.hosted_zone_id == "") || (var.custom_domain != "" && var.hosted_zone_id != "")
    error_message = "hosted_zone_id must be provided when custom_domain is set, and must be empty when custom_domain is not set."
  }
}

variable "enable_spa_mode" {
  description = "Enable Single Page Application mode by redirecting 404s to index.html with 200 status code."
  type        = bool
  default     = false
}
