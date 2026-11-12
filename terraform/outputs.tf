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

output "instance_public_ip" {
  description = "Публичный IP — открой http://<этот_IP>:5000 в браузере"
  value       = aws_instance.app.public_ip
}

output "ssh_command" {
  description = "Команда для подключения по SSH"
  value       = "ssh -i ~/.ssh/aws-devops-todo ubuntu@${aws_instance.app.public_ip}"
}
