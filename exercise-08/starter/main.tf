terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# TODO: random suffix shared by both bucket names

# TODO: call ./modules/s3-bucket for the logs bucket (no versioning)

# TODO: call ./modules/s3-bucket for the backups bucket (versioning enabled)
