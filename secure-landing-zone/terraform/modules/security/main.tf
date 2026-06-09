resource "aws_security_group" "bastion_Sg" {
  name_prefix = "${var.project_name}-bastion-sg"
  vpc_id = var.vpc_id
  description = "security group for bastion host"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}




resource "aws_security_group" "priv_bastion_Sg" {
  name_prefix = "${var.project_name}-private-bastion-sg"
  vpc_id = var.vpc_id
  description = "security group for bastion host"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_Sg.id]
  }

    ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
  egress {
    description = "HTTPS outbound via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}