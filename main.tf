provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "my_instance" {
  ami           = "ami-0a7d80731ae1b2435"
  instance_type = "t3.micro"

  tags = {
    Name = "terraform-example"
  }
}