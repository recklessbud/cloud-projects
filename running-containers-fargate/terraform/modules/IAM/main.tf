

resource "random_password" "suffix" {
  length  = 6
  special = false
  upper   = false
}


locals {
    execution_role_name = "ecs-execution-role-${random_password.suffix.result}"
}







resource "aws_iam_role" "ecs_execution_role" {
  name = local.execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = local.execution_role_name
  }
}


resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}