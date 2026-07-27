resource "random_password" "suffix" {
  length  = 6
  special = false
  upper   = false
}




resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-${random_password.suffix.result}"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  # Inbound rule for application port
  ingress {
    description = "Application port"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress{
    description = "TCP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules for internet access (required for Fargate)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-${random_password.suffix.result}"
  }
}