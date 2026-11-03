variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: xx-xxxx-x (e.g., us-east-1)."
  }
}

# TODO: bucket_prefix (default "ig2i-ex09", 3 to 20 characters)

# TODO: instance_counts, a map(number) with one entry per workspace
