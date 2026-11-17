terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state: state хранится в S3, блокировка — lock-файлом в том же бакете
  backend "s3" {
    bucket       = "devops-todo-app-tfstate-965317436147"
    key          = "devops-todo-app/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
