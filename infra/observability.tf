locals {
  api_access_log_group_name = "/aws/apigateway/${var.project_name}-access"
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = local.api_access_log_group_name
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Purpose = "API access audit records"
  })
}

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    sid     = "AllowApiGatewayAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_gateway_logging" {
  name               = "${var.project_name}-api-gateway-logging-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "api_gateway_logging" {
  statement {
    sid       = "DiscoverLogDestinations"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid    = "WriteApiAccessLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.api_access.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "api_gateway_logging" {
  name   = "${var.project_name}-api-gateway-logging-policy"
  role   = aws_iam_role.api_gateway_logging.id
  policy = data.aws_iam_policy_document.api_gateway_logging.json
}

resource "aws_api_gateway_account" "logging" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn

  depends_on = [
    aws_iam_role_policy.api_gateway_logging,
  ]
}

resource "aws_api_gateway_method_settings" "create_finding" {
  rest_api_id = aws_api_gateway_rest_api.evidence.id
  stage_name  = aws_api_gateway_stage.local.stage_name
  method_path = "${aws_api_gateway_resource.findings.path_part}/${aws_api_gateway_method.create_finding.http_method}"

  settings {
    metrics_enabled        = true
    logging_level          = "OFF"
    data_trace_enabled     = false
    throttling_rate_limit  = 2
    throttling_burst_limit = 5
  }
}