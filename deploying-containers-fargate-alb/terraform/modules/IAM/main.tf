resource "random_string" "suffix" {
    length  = 8
    special = false
    upper   = false
}


resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecRole-${random_string.suffix.result}"

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
    Name = "ecsTaskExecRole-${random_string.suffix.result}"
  }
}



resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole-${random_string.suffix.result}"

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
    Name = "ecsTaskRole-${random_string.suffix.result}"
  }
}


resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecsTaskRolePolicy-${random_string.suffix.result}"
  role = aws_iam_role.ecs_task_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  
}