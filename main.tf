provider "aws" {
  region = "us-east-1"
}

variable "server_port" {
  description = "Port for web server"
  type        = number
  default     = 8080
}

resource "aws_launch_template" "my_instance" {
  image_id               = "ami-0a7d80731ae1b2435"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.webServer_sg.id]

  user_data                   = base64encode(
    <<-EOF
    #!/bin/bash
    echo "Hello, World!" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF
  )  
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_autoscaling_group" "webServer_asg" {
  launch_template {
    id = aws_launch_template.my_instance.id
    version = "$Latest"
  }

  min_size = 2
  max_size = 3
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.targetGroup.arn]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "Terraform-asg-example"
    propagate_at_launch = true
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

resource "aws_security_group" "alb_sg" {
  name = "terraform-example-alb-sg"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "webServer_lb" {
  name = "Terraform-lb-example"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "targetGroup" {
  name = "terraform-lb-tg"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webServer_lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found"
      status_code = 404
    }
  }
}

resource "aws_lb_listener_rule" "alblistener" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.targetGroup.arn
  }
}

output "alb_dns_name" {
  value       = aws_lb.webServer_lb.dns_name
  description = "Lb DNS"
}