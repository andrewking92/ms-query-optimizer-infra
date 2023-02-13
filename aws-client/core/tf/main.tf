provider "aws" {
  region = var.aws_region
}


provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_api_pub_key
  private_key = var.mongodb_atlas_api_pri_key
}


data "http" "ip" {
  url = "https://ifconfig.me/ip"
}


locals {
  client_public_ip = data.http.ip.response_body
}


# Network

# Create VPC with DNS hostnames enabled
resource "aws_vpc" "ms-query-optimizer" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

  tags = {
    Name = "ms-query-optimizer"
  }
}

# Create subnet with public IPs declared
resource "aws_subnet" "subnet_ms-query-optimizer" {
  vpc_id            = aws_vpc.ms-query-optimizer.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.aws_availability_zone

  map_public_ip_on_launch = true
  
  tags = {
    Name = "ms-query-optimizer"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "ms-query-optimizer" {
  vpc_id = aws_vpc.ms-query-optimizer.id

  tags = {
    Name = "ms-query-optimizer"
  }
}

# Create internet access route in route table
resource "aws_route" "ms-query-optimizer" {
  route_table_id         = aws_vpc.ms-query-optimizer.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ms-query-optimizer.id
}


resource "aws_route53_record" "ms-query-optimizer" {
  zone_id = "${var.aws_host_zone_id}"
  name = var.fqdn
  type = "A"
  ttl = "300"
  records = [ aws_instance.ms-query-optimizer.private_ip ]
}




# Security

# Create security group
resource "aws_security_group" "ms-query-optimizer" {
  name        = "ms-query-optimizer_security_group"
  description = "Allow SSH + TCP inbound traffic"
  vpc_id      = aws_vpc.ms-query-optimizer.id

  ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
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

resource "aws_security_group_rule" "ms-query-optimizer" {
  depends_on = [aws_security_group.ms-query-optimizer]
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.ms-query-optimizer.id
  security_group_id = aws_security_group.ms-query-optimizer.id
}


# Compute

# Create EC2 instance with default root volume
resource "aws_instance" "ms-query-optimizer" {
  ami                     = var.ami
  instance_type           = var.instance_type
  
  subnet_id               = aws_subnet.subnet_ms-query-optimizer.id

  vpc_security_group_ids  = [ aws_security_group.ms-query-optimizer.id ]
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
resource "aws_ebs_volume" "ms-query-optimizer" {
  availability_zone = var.aws_availability_zone
  size              = var.aws_ebs_volume_size
}


# Attach volume to EC2 instance
resource "aws_volume_attachment" "ms-query-optimizer" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.ms-query-optimizer.id
  instance_id = aws_instance.ms-query-optimizer.id
  force_detach = true
}



# Add Client IP to Atlas Network Access List
resource "mongodbatlas_project_ip_access_list" "ms-query-optimizer" {
      project_id = var.mongodb_atlas_project_id
      ip_address = aws_instance.ms-query-optimizer.public_ip
      comment    = "ms-query-optimizer-client"
}



# Tasks

# Run Ansible Playbooks
resource "null_resource" "ms-query-optimizer" {
  depends_on = [aws_volume_attachment.ms-query-optimizer]

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
        type        = "ssh"
        user        = var.ssh_user
        private_key = file(var.private_key)
        host        = aws_instance.ms-query-optimizer.public_ip
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.ms-query-optimizer.public_ip}, ../ansible/playbook.yml"
  }
}