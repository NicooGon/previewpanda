resource "aws_iam_role" "lambda_exec" {
  name = "pp-${var.env_name}-lambda-exec"

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
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/lambda/pp-${var.env_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "app" {
  function_name = "pp-${var.env_name}"
  role          = aws_iam_role.lambda_exec.arn

  # Handler y runtime definidos en app/Dockerfile
  package_type = "Image"
  image_uri    = var.image_uri

  # Debe coincidir con la arquitectura del build (amd64)
  architectures = ["x86_64"]

  timeout     = 15
  memory_size = 512

  environment {
    variables = {
      PR_NUMBER  = var.pr_number
      COMMIT_SHA = coalesce(var.commit_sha, "NOT_CONFIGURED")
    }
  }

  depends_on = [aws_cloudwatch_log_group.app_logs]
}

resource "aws_lambda_function_url" "app_url" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "public_url_access" {
  statement_id           = "AllowPublicFunctionUrlAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app.function_name
  principal              = "*"
  function_url_auth_type = "NONE"

  depends_on = [aws_lambda_function_url.app_url]
}

resource "aws_lambda_permission" "public_invoke_access" {
  statement_id  = "AllowPublicInvokeAccess"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "*"

  depends_on = [aws_lambda_permission.public_url_access]
}
