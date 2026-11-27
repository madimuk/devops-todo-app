variable "project_name" {
  description = "Название проекта — используется как префикс в тегах ресурсов"
  type        = string
  default     = "devops-todo-app"
}

variable "vpc_cidr" {
  description = "CIDR-блок для VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR-блок для публичной подсети"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone для подсети"
  type        = string
  default     = "eu-central-1a"
}

variable "instance_type" {
  description = "Тип EC2-инстанса"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "Public SSH key for EC2 access"
  type        = string
}
