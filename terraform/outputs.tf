output "vpc_id" {
  description = "ID созданной VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID публичной подсети"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID Security Group"
  value       = aws_security_group.app.id
}

output "instance_id" {
  description = "ID EC2-инстанса"
  value       = aws_instance.app.id
}
