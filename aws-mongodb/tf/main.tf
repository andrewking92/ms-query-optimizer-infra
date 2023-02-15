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


# Compute

# Create EC2 instance with default root volume
resource "aws_instance" "ms-query-optimizer" {
  count = 3
  ami                     = var.ami
  instance_type           = var.instance_type
  
  subnet_id               = var.subnet_ms_query_optimizer_id

  vpc_security_group_ids  = [ var.security_group_ms_query_optimizer_id ]
  key_name                = var.key_name

  tags = {
    Name = var.instance_name
  }

  root_block_device {
    volume_size = var.aws_instance_root_block_device_volume_size
  }
}



# Storage

# Create 10 GB volume
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
    command = "ansible-playbook -i ${aws_instance.ms-query-optimizer[0].public_ip},${aws_instance.ms-query-optimizer[1].public_ip},${aws_instance.ms-query-optimizer[2].public_ip} ../ansible/playbook.yml"

  }
}