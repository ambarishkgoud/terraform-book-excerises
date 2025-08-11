provider "aws" {
  region = "us-east-1"
}

variable "server_port" {
  description = "Port for web server"
  type        = number
  default     = 8080
}

resource "aws_instance" "my_instance" {
  ami                    = "ami-0a7d80731ae1b2435"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.webServer_sg.id]

  user_data                   = <<-EOF
    #!/bin/bash
    echo "Hello, World!" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF
  user_data_replace_on_change = true

  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "webServer_sg" {
  name = "terraform-example-instance-sg"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_ip" {
  value       = aws_instance.my_instance.public_ip
  description = "Web Server public IP"
}