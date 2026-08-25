import json

from app.handler import lambda_handler


def invoke(body: object) -> dict:
    event = {"body": json.dumps(body)}
    return lambda_handler(event, None)


def response_body(response: dict) -> dict:
    return json.loads(response["body"])


def test_valid_finding_returns_201() -> None:
    response = invoke(
        {
            "title": "Public S3 bucket",
            "severity": "high",
            "description": "The evidence bucket permits public access.",
        }
    )

    body = response_body(response)

    assert response["statusCode"] == 201
    assert body["title"] == "Public S3 bucket"
    assert body["severity"] == "high"
    assert body["status"] == "open"
    assert body["findingId"]
    assert body["createdAt"]


def test_missing_required_field_returns_400() -> None:
    response = invoke(
        {
            "title": "Missing description",
            "severity": "moderate",
        }
    )

    assert response["statusCode"] == 400
    assert response_body(response)["fields"] == ["description"]


def test_invalid_severity_returns_400() -> None:
    response = invoke(
        {
            "title": "Invalid severity",
            "severity": "extreme",
            "description": "Severity is outside the authorized values.",
        }
    )

    assert response["statusCode"] == 400
    assert response_body(response)["message"] == "Severity is invalid."


def test_invalid_json_returns_400() -> None:
    response = lambda_handler({"body": "{invalid-json"}, None)

    assert response["statusCode"] == 400
    assert response_body(response)["message"] == "Request body must be valid JSON."
