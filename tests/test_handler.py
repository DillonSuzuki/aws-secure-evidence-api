import json

import pytest

from app import authentication, handler

EXPECTED_TOKEN = "expected-token"


@pytest.fixture(autouse=True)
def configure_expected_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        authentication,
        "_get_expected_token",
        lambda: EXPECTED_TOKEN,
    )


def invoke(body: object, token: str | None = EXPECTED_TOKEN) -> dict:
    headers = {}

    if token is not None:
        headers["Authorization"] = f"Bearer {token}"

    event = {
        "headers": headers,
        "body": json.dumps(body),
    }

    return handler.lambda_handler(event, None)


def response_body(response: dict) -> dict:
    return json.loads(response["body"])


def valid_finding() -> dict:
    return {
        "title": "Public S3 bucket",
        "severity": "high",
        "description": "The evidence bucket permits public access.",
    }


def test_valid_finding_is_persisted_and_returns_201(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stored_findings: list[dict] = []

    monkeypatch.setattr(handler, "_persist_finding", stored_findings.append)

    response = invoke(valid_finding())
    body = response_body(response)

    assert response["statusCode"] == 201
    assert body["title"] == "Public S3 bucket"
    assert body["severity"] == "high"
    assert body["status"] == "open"
    assert body["findingId"]
    assert body["createdAt"]
    assert stored_findings == [body]


def test_missing_token_returns_403_without_persistence(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stored_findings: list[dict] = []

    monkeypatch.setattr(handler, "_persist_finding", stored_findings.append)

    response = invoke(valid_finding(), token=None)

    assert response["statusCode"] == 403
    assert response_body(response)["message"] == "Forbidden."
    assert stored_findings == []


def test_incorrect_token_returns_403_without_persistence(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stored_findings: list[dict] = []

    monkeypatch.setattr(handler, "_persist_finding", stored_findings.append)

    response = invoke(valid_finding(), token="incorrect-token")

    assert response["statusCode"] == 403
    assert response_body(response)["message"] == "Forbidden."
    assert stored_findings == []


def test_secret_failure_returns_403_without_persistence(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stored_findings: list[dict] = []

    def raise_secret_error() -> str:
        raise RuntimeError("Simulated secret failure")

    monkeypatch.setattr(
        authentication,
        "_get_expected_token",
        raise_secret_error,
    )
    monkeypatch.setattr(handler, "_persist_finding", stored_findings.append)

    response = invoke(valid_finding())

    assert response["statusCode"] == 403
    assert response_body(response)["message"] == "Forbidden."
    assert stored_findings == []


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
    response = handler.lambda_handler(
        {
            "headers": {
                "Authorization": f"Bearer {EXPECTED_TOKEN}",
            },
            "body": "{invalid-json",
        },
        None,
    )

    assert response["statusCode"] == 400
    assert response_body(response)["message"] == "Request body must be valid JSON."


def test_persistence_failure_returns_500(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fail_to_persist(_finding: dict) -> None:
        raise RuntimeError("Simulated DynamoDB failure.")

    monkeypatch.setattr(handler, "_persist_finding", fail_to_persist)

    response = invoke(valid_finding())

    assert response["statusCode"] == 500
    assert response_body(response)["message"] == "Finding could not be stored."
