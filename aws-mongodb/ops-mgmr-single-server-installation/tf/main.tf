terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}


data "http" "ip" {
  url = "https://ifconfig.me/ip"
}


locals {
  client_public_ip = data.http.ip.response_body
}



# Network

# Create VPC with DNS hostnames enabled
resource "aws_vpc" "ops_manager" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

  tags = {
    Name = "ops_manager"
  }
}

# Create subnet with public IPs declared
resource "aws_subnet" "subnet_ops_manager" {
  vpc_id            = aws_vpc.ops_manager.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.aws_availability_zone

  map_public_ip_on_launch = true
  
  tags = {
    Name = "ops_manager"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "ops_manager" {
  vpc_id = aws_vpc.ops_manager.id

  tags = {
    Name = "ops_manager"
  }
}

# Create internet access route in route table
resource "aws_route" "ops_manager" {
  route_table_id         = aws_vpc.ops_manager.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ops_manager.id
}


resource "aws_route53_record" "ops_manager" {
  zone_id = "${var.aws_host_zone_id}"
  name = var.fqdn
  type = "A"
  ttl = "300"
  records = [ aws_instance.ops_manager.private_ip ]
}



# Security

# Create security group
resource "aws_security_group" "ops_manager" {
  name        = "ops_manager_security_group"
  description = "Allow SSH + TCP inbound traffic"
  vpc_id      = aws_vpc.ops_manager.id

  ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "${local.client_public_ip}/32" ]
  }

  ingress {
    description      = "TCP to VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = [ "${local.client_public_ip}/32" ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "ops_manager" {
  depends_on = [aws_security_group.ops_manager]
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.ops_manager.id
  security_group_id = aws_security_group.ops_manager.id
}


# Compute

# Create EC2 instance with default root volume
resource "aws_instance" "ops_manager" {
  ami                     = var.ami
  instance_type           = var.instance_type
  
  subnet_id               = aws_subnet.subnet_ops_manager.id

  vpc_security_group_ids  = [ aws_security_group.ops_manager.id ]
  key_name                = var.key_name

  tags = {
    Name = var.instance_name
  }

  root_block_device {
    volume_size = var.aws_instance_root_block_device_volume_size
  }
}



# Storage

# Create 30 GB volume
resource "aws_ebs_volume" "ops_manager" {
  availability_zone = var.aws_availability_zone
  size              = var.aws_ebs_volume_size
}


# Attach volume to EC2 instance
resource "aws_volume_attachment" "ops_manager" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.ops_manager.id
  instance_id = aws_instance.ops_manager.id
  force_detach = true
}



# Tasks

# Run Ansible Playbooks
resource "null_resource" "ops_manager" {
  depends_on = [aws_volume_attachment.ops_manager]

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
        type        = "ssh"
        user        = var.ssh_user
        private_key = file(var.private_key)
        host        = aws_instance.ops_manager.public_ip
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.ops_manager.public_ip}, ../ansible/playbook.yml"
  }
}