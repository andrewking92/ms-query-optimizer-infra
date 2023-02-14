output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ops_manager.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ops_manager.public_ip
}

output "instance_state" {
  description = "State of the EC2 instance"
  value       = aws_instance.ops_manager.instance_state
}

output "root_block_device" {
  description = "Root Block Device of the EC2 instance"
  value       = aws_instance.ops_manager.root_block_device[0].volume_id
}