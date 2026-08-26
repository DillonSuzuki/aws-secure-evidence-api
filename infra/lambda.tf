locals {
  finding_ingest_function_name = "${var.project_name}-finding-ingest"
}

data "archive_file" "finding_ingest" {
  type        = "zip"
  output_path = "${path.module}/finding-ingest.zip"

  source {
    content  = file("${path.module}/../app/__init__.py")
    filename = "app/__init__.py"
  }

  source {
    content  = file("${path.module}/../app/authentication.py")
    filename = "app/authentication.py"
  }

  source {
    content  = file("${path.module}/../app/handler.py")
    filename = "app/handler.py"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "finding_ingest" {
  name               = "${var.project_name}-finding-ingest-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "finding_ingest" {
  statement {
    sid     = "WriteFindings"
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]
    resources = [
      aws_dynamodb_table.findings.arn,
    ]
  }

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
    sid    = "WriteFunctionLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.finding_ingest.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "finding_ingest" {
  name   = "${var.project_name}-finding-ingest-policy"
  role   = aws_iam_role.finding_ingest.id
  policy = data.aws_iam_policy_document.finding_ingest.json
}

resource "aws_cloudwatch_log_group" "finding_ingest" {
  name              = "/aws/lambda/${local.finding_ingest_function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_lambda_function" "finding_ingest" {
  function_name = local.finding_ingest_function_name
  description   = "Validates and stores security findings."
  role          = aws_iam_role.finding_ingest.arn

  filename         = data.archive_file.finding_ingest.output_path
  source_code_hash = data.archive_file.finding_ingest.output_base64sha256

  handler       = "app.handler.lambda_handler"
  runtime       = "python3.14"
  architectures = ["x86_64"]
  memory_size   = 256
  timeout       = 10

  environment {
    variables = {
      FINDINGS_TABLE_NAME  = aws_dynamodb_table.findings.name
      AUTHORIZER_SECRET_ID = aws_secretsmanager_secret.api_authorizer.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.finding_ingest,
    aws_iam_role_policy.finding_ingest,
  ]

  tags = local.common_tags
}