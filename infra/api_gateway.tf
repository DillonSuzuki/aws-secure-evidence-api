resource "aws_api_gateway_rest_api" "evidence" {
  name        = var.project_name
  description = "Validated intake API for security findings and evidence."

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "findings" {
  rest_api_id = aws_api_gateway_rest_api.evidence.id
  parent_id   = aws_api_gateway_rest_api.evidence.root_resource_id
  path_part   = "findings"
}

resource "aws_api_gateway_model" "finding_request" {
  rest_api_id  = aws_api_gateway_rest_api.evidence.id
  name         = "FindingRequest"
  description  = "Permitted structure for finding-intake requests."
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Finding request"
    type      = "object"

    required = [
      "title",
      "severity",
      "description",
    ]

    additionalProperties = false

    properties = {
      title = {
        type      = "string"
        minLength = 1
        maxLength = 200
      }

      severity = {
        type = "string"
        enum = [
          "low",
          "moderate",
          "high",
          "critical",
        ]
      }

      description = {
        type      = "string"
        minLength = 1
        maxLength = 4000
      }
    }
  })
}

resource "aws_api_gateway_request_validator" "body" {
  rest_api_id                 = aws_api_gateway_rest_api.evidence.id
  name                        = "validate-finding-body"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_method" "create_finding" {
  rest_api_id   = aws_api_gateway_rest_api.evidence.id
  resource_id   = aws_api_gateway_resource.findings.id
  http_method   = "POST"
  authorization = "NONE"

  api_key_required     = false
  request_validator_id = aws_api_gateway_request_validator.body.id

  request_models = {
    "application/json" = aws_api_gateway_model.finding_request.name
  }
}

resource "aws_api_gateway_integration" "create_finding" {
  rest_api_id = aws_api_gateway_rest_api.evidence.id
  resource_id = aws_api_gateway_resource.findings.id
  http_method = aws_api_gateway_method.create_finding.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.finding_ingest.invoke_arn
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowFindingIntakeApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.finding_ingest.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.evidence.execution_arn}/*/POST/findings"
}

resource "aws_api_gateway_deployment" "evidence" {
  rest_api_id = aws_api_gateway_rest_api.evidence.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.findings.id,
      aws_api_gateway_method.create_finding.id,
      aws_api_gateway_integration.create_finding.id,
      aws_api_gateway_model.finding_request.schema,
      aws_api_gateway_request_validator.body.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.create_finding,
  ]
}

resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.evidence.id
  deployment_id = aws_api_gateway_deployment.evidence.id
  stage_name    = "local"

  tags = local.common_tags
}