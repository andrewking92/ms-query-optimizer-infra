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


# Compute

# Create EC2 instance with default root volume
resource "aws_instance" "mongod" {
  ami                     = var.ami
  instance_type           = var.instance_type

  subnet_id               = var.aws_subnet_id

  vpc_security_group_ids  = [ var.aws_security_group_id ]
  key_name                = var.key_name

  tags = {
    Name = var.instance_name
  }
}



# Tasks

# Run Ansible Playbooks
resource "null_resource" "mongod" {
  depends_on = [aws_instance.mongod]

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
        type        = "ssh"
        user        = var.ssh_user
        private_key = file(var.private_key)
        host        = aws_instance.mongod.public_ip
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.mongod.public_ip}, ../ansible/playbook.yml"
  }

}