terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Отдельный state: роль для CI не должна удаляться при destroy EC2-стенда
  backend "s3" {
    bucket       = "devops-todo-app-tfstate-965317436147"
    key          = "github-oidc/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

locals {
  # Immutable sub prefix: gh api repos/madimuk/devops-todo-app/actions/oidc/customization/sub
  sub_prefix = "repo:madimuk@156674890/devops-todo-app@1354639612"
}
# OIDC-провайдер GitHub (один на аккаунт)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Роль может взять только этот репо: из main или из pull_request
resource "aws_iam_role" "github_plan" {
  name = "github-actions-devops-todo-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "${local.sub_prefix}:ref:refs/heads/main",
            "${local.sub_prefix}:pull_request",
          ]
        }
      }
    }]
  })
}

# Только чтение — для terraform plan этого хватает
resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# plan с use_lockfile создаёт/удаляет .tflock — разрешаем запись только туда
resource "aws_iam_role_policy" "tfstate_lock" {
  name = "tfstate-lock-write"
  role = aws_iam_role.github_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:aws:s3:::devops-todo-app-tfstate-965317436147/devops-todo-app/terraform.tfstate.tflock"
    }]
  })
}

output "plan_role_arn" {
  value = aws_iam_role.github_plan.arn
}
