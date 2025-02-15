resource "null_resource" "create_virtualenv" {
  provisioner "local-exec" {
    command     = "python3 -m venv venv && . venv/bin/activate && pip install -r requirements.txt"
    working_dir = "${path.module}/resources/ses-lambda/"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "copy_dependencies" {
  depends_on = [null_resource.create_virtualenv]

  provisioner "local-exec" {
    command     = "mkdir -p deployable && cp -r venv/lib/python3.12/site-packages/* deployable/"
    working_dir = "${path.module}/resources/ses-lambda/"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

# Step 3: Copy your Lambda code to the deployment directory
resource "null_resource" "copy_lambda_code" {
  depends_on = [null_resource.copy_dependencies]

  provisioner "local-exec" {
    command     = "cp handler.py deployable/"
    working_dir = "${path.module}/resources/ses-lambda/"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

data "archive_file" "lambda_zip" {
  depends_on  = [null_resource.copy_lambda_code]
  type        = "zip"
  source_dir  = "${path.module}/resources/ses-lambda/deployable"
  output_path = "${path.module}/resources/ses-lambda/lambda_function.zip"
}


# Step 5: Clean up the virtual environment
resource "null_resource" "cleanup" {
  depends_on = [data.archive_file.lambda_zip]

  provisioner "local-exec" {
    command     = "rm -rf venv deployable"
    working_dir = "${path.module}/resources/ses-lambda/"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "aws_lambda_function" "this" {
  function_name = "ContactFormLambda"
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.this.arn
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      "RECAPTCHA_KEY" = var.recaptcha_key
    }
  }
}

resource "aws_iam_role" "this" {
  name = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name   = "AllowSendEmailPolicy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

data "aws_iam_policy_document" "this" {
  statement {
    actions   = ["ses:SendEmail"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["dynamodb:GetItem"]
    effect    = "Allow"
    resources = [aws_dynamodb_table.this.arn]
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_rest_api" "this" {
  name        = "ContactFormAPI"
  description = "API to handle contact form submissions"
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "submit"
}

resource "aws_api_gateway_method" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}

resource "aws_dynamodb_table" "this" {
  name         = "DomainToEmailTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Host"

  attribute {
    name = "Host"
    type = "S"
  }
}