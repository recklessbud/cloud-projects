resource "random_string" "suffix" {
    length  = 8
    special = false
    upper   = false
  
}


resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-${random_string.suffix.result}"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_cidr_blocks
  }

  tags = {
    Name = "${var.alb_name}-sg-${random_string.suffix.result}"
  }

}


# fargate tasks
resource "aws_security_group" "fargate_tasks" {
    name = "${var.fargate_service}-sg-${random_string.suffix.result}"
    description = "Security group for Fargate tasks"
    vpc_id = var.vpc_id

    ingress {
        from_port = var.container_port
        to_port = var.container_port
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = var.allowed_cidr_blocks
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = var.allowed_cidr_blocks
    }

    tags = {
        Name = "${var.fargate_service}-sg-${random_string.suffix.result}"
    }

}