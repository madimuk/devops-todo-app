terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Провайдер для настоящего AWS.
# Access Key/Secret Key берутся автоматически из результата "aws configure",
# поэтому здесь их указывать не нужно и не следует.
provider "aws" {
  region = "eu-central-1"
}
