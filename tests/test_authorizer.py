from app import authorizer

METHOD_ARN = "arn:aws:execute-api:us-east-1:000000000000:example/local/POST/findings"


def invoke(token: str | None) -> dict:
    headers = {}

    if token is not None:
        headers["Authorization"] = f"Bearer {token}"

    return authorizer.lambda_handler(
        {
            "headers": headers,
            "methodArn": METHOD_ARN,
        },
        None,
    )


def policy_effect(response: dict) -> str:
    return response["policyDocument"]["Statement"][0]["Effect"]


def test_matching_token_is_allowed(monkeypatch) -> None:
    monkeypatch.setattr(
        authorizer,
        "_get_expected_token",
        lambda: "expected-token",
    )

    response = invoke("expected-token")

    assert policy_effect(response) == "Allow"
    assert response["context"]["authenticated"] is True


def test_incorrect_token_is_denied(monkeypatch) -> None:
    monkeypatch.setattr(
        authorizer,
        "_get_expected_token",
        lambda: "expected-token",
    )

    response = invoke("incorrect-token")

    assert policy_effect(response) == "Deny"


def test_missing_token_is_denied(monkeypatch) -> None:
    response = invoke(None)

    assert policy_effect(response) == "Deny"


def test_malformed_authorization_header_is_denied(monkeypatch) -> None:
    monkeypatch.setattr(
        authorizer,
        "_get_expected_token",
        lambda: "expected-token",
    )

    response = authorizer.lambda_handler(
        {
            "headers": {"Authorization": "Basic expected-token"},
            "methodArn": METHOD_ARN,
        },
        None,
    )

    assert policy_effect(response) == "Deny"


def test_secret_retrieval_failure_is_denied(monkeypatch) -> None:
    def raise_secret_error() -> str:
        raise RuntimeError("Simulated secret failure")

    monkeypatch.setattr(
        authorizer,
        "_get_expected_token",
        raise_secret_error,
    )

    response = invoke("expected-token")

    assert policy_effect(response) == "Deny"
