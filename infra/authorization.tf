locals {
  finding_authorizer_function_name = "${var.project_name}-finding-authorizer"
  finding_authorizer_secret_name   = "${var.project_name}/api-authorizer-token"
}

resource "aws_secretsmanager_secret" "api_authorizer" {
  name                    = local.finding_authorizer_secret_name
  description             = "Bearer token used by the local finding API authorizer."
  kms_key_id              = aws_kms_key.project.arn
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Purpose = "API client authentication"
  })
}

data "archive_file" "finding_authorizer" {
  type        = "zip"
  output_path = "${path.module}/finding-authorizer.zip"

  source {
    content  = file("${path.module}/../app/__init__.py")
    filename = "app/__init__.py"
  }

  source {
    content  = file("${path.module}/../app/authentication.py")
    filename = "app/authentication.py"
  }

  source {
    content  = file("${path.module}/../app/authorizer.py")
    filename = "app/authorizer.py"
  }
}

resource "aws_iam_role" "finding_authorizer" {
  name               = "${local.finding_authorizer_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "finding_authorizer" {
  statement {
    sid     = "ReadAuthorizerSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]

    resources = [
      aws_secretsmanager_secret.api_authorizer.arn,
    ]
  }

  statement {
    sid     = "DecryptAuthorizerSecret"
    effect  = "Allow"
    actions = ["kms:Decrypt"]

    resources = [
      aws_kms_key.project.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "WriteAuthorizerLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.finding_authorizer.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "finding_authorizer" {
  name   = "${local.finding_authorizer_function_name}-policy"
  role   = aws_iam_role.finding_authorizer.id
  policy = data.aws_iam_policy_document.finding_authorizer.json
}

resource "aws_cloudwatch_log_group" "finding_authorizer" {
  name              = "/aws/lambda/${local.finding_authorizer_function_name}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Purpose = "Authorizer execution records"
  })
}

resource "aws_lambda_function" "finding_authorizer" {
  function_name = local.finding_authorizer_function_name
  description   = "Validates API bearer tokens against Secrets Manager."
  role          = aws_iam_role.finding_authorizer.arn

  filename         = data.archive_file.finding_authorizer.output_path
  source_code_hash = data.archive_file.finding_authorizer.output_base64sha256

  runtime = "python3.14"
  handler = "app.authorizer.lambda_handler"

  memory_size = 128
  timeout     = 5

  environment {
    variables = {
      AUTHORIZER_SECRET_ID = aws_secretsmanager_secret.api_authorizer.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.finding_authorizer,
    aws_iam_role_policy.finding_authorizer,
  ]

  tags = local.common_tags
}

resource "aws_api_gateway_authorizer" "finding_submitter" {
  name        = "${var.project_name}-finding-submitter-authorizer"
  rest_api_id = aws_api_gateway_rest_api.evidence.id

  type                             = "REQUEST"
  authorizer_uri                   = aws_lambda_function.finding_authorizer.invoke_arn
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_lambda_permission" "allow_api_gateway_authorizer" {
  statement_id  = "AllowApiGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.finding_authorizer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.evidence.execution_arn}/authorizers/${aws_api_gateway_authorizer.finding_submitter.id}"
}