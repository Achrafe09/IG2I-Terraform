terraform {
  required_version = "~> 1.11"

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

# TODO: random suffix

# TODO: state bucket, protected against destroy

# TODO: versioning of the state bucket

# TODO: server-side encryption of the state bucket
