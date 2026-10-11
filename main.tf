terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "ansible_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Ansible-Automation-VPC"
  }
}
resource "aws_subnet" "ansible_public_subnet" {
  vpc_id                  = aws_vpc.ansible_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ansible-Public-Subnet"
  }
}
resource "aws_internet_gateway" "ansible_igw" {
  vpc_id = aws_vpc.ansible_vpc.id

  tags = {
    Name = "Ansible-Automation-IGW"
  }
}
resource "aws_route_table" "ansible_public_rt" {
  vpc_id = aws_vpc.ansible_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ansible_igw.id
  }

  tags = {
    Name = "Ansible-Public-RouteTable"
  }
}

resource "aws_route_table_association" "ansible_public_assoc" {
  subnet_id      = aws_subnet.ansible_public_subnet.id
  route_table_id = aws_route_table.ansible_public_rt.id
}
variable "ssh_allowed_cidr" {
  description = "Your public IPv4 address followed by /32"
  type        = string
}

resource "aws_security_group" "ansible_sg" {
  name        = "Ansible-Automation-SG"
  description = "Security group for five Ansible-managed Linux servers"
  vpc_id      = aws_vpc.ansible_vpc.id

  ingress {
    description = "SSH from administrator only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP for Apache web servers"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Ansible-Automation-SG"
  }
}
resource "aws_key_pair" "ansible_key" {
  key_name   = "Ansible-Automation-Key"
  public_key = file(pathexpand("~/.ssh/aws-ansible-lab.pub"))

  tags = {
    Name = "Ansible-Automation-Key"
  }
}

data "aws_ssm_parameter" "amazon_linux_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "ansible_servers" {
  count = 5

  ami                         = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.ansible_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ansible_key.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "Ansible-Linux-Server-${count.index + 1}"
  }
}
