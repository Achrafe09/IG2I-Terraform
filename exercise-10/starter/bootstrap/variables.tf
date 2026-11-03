variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: xx-xxxx-x (e.g., us-east-1)."
  }
}

# TODO: bucket_prefix (default "ig2i-tfstate", 3 to 20 characters)
