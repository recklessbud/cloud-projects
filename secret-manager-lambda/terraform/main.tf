

module "secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.3"

  name                    = local.secret_name
  description             = var.secret_description
  recovery_window_in_days = var.secret_recovery_window
  kms_key_id              = var.kms_key_id


  secret_string = jsonencode(var.sample_secret_values)

  ignore_secret_changes = true

  enable_rotation = var.enable_secret_rotation
  rotation_rules = var.enable_secret_rotation ? {
    automatically_after_days = var.rotation_days
  } : {}

  tags = local.common_tags

}



resource "aws_iam_role" "lambda_exec_role" {
  name = local.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}


resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "secrets_access_policy" {
  name        = "SecretAccess-${local.resource_suffix}"
  description = "policy for lambda to access secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          module.secrets_manager.secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
            "lambda:InvokeFunction"
        ]
        Resource = [
         "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.lambda_function_name}"
        ]
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "secrets_access_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.secrets_access_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/../src/lambda/main.zip"

  source {
    content = templatefile("${path.module}/../src/lambda/main.py.tpl", {
      secret_name = module.secrets_manager.secret_name
    })
    filename = "main.py"
  }
}


resource "aws_lambda_function" "secret_demo" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "main.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [local.extensions_layer_arn]


  environment {
    variables = {
      SECRET_NAME                                  = module.secrets_manager.secret_name
      PARAMETERS_SECRETS_EXTENSION_CACHE_ENABLED   = tostring(var.extension_cache_enabled)
      PARAMETERS_SECRETS_EXTENSION_CACHE_SIZE      = tostring(var.extension_cache_size)
      PARAMETERS_SECRETS_EXTENSION_MAX_CONNECTIONS = tostring(var.extension_max_connections)
      PARAMETERS_SECRETS_EXTENSION_HTTP_PORT       = tostring(var.extension_http_port)
    }
  }


  depends_on = [aws_iam_role_policy_attachment.secrets_access_policy_attachment,
    aws_iam_role_policy_attachment.lambda_exec_policy,
    aws_cloudwatch_log_group.lambda_logs
  ]
  tags = local.common_tags
}


resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.secret_demo.function_name
  authorization_type = "NONE"


  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }

}
