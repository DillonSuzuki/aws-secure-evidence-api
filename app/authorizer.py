import hmac
import os

import boto3
from botocore.exceptions import BotoCoreError, ClientError

SECRET_ID_ENVIRONMENT_VARIABLE = "AUTHORIZER_SECRET_ID"


def _get_expected_token() -> str:
    secret_id = os.environ.get(SECRET_ID_ENVIRONMENT_VARIABLE)

    if not secret_id:
        raise RuntimeError("Authorizer secret identifier is not configured.")

    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=secret_id)
    secret = response.get("SecretString")

    if not isinstance(secret, str) or not secret:
        raise RuntimeError("Authorizer secret value is unavailable.")

    return secret


def _get_bearer_token(event: dict) -> str | None:
    headers = event.get("headers")

    if not isinstance(headers, dict):
        return None

    authorization_header = next(
        (
            value
            for name, value in headers.items()
            if isinstance(name, str)
            and name.lower() == "authorization"
            and isinstance(value, str)
        ),
        None,
    )

    if authorization_header is None:
        return None

    scheme, separator, token = authorization_header.partition(" ")

    if separator and scheme.lower() == "bearer" and token.strip():
        return token.strip()

    return None


def _policy(effect: str, method_arn: str) -> dict:
    return {
        "principalId": "local-api-client",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": method_arn,
                }
            ],
        },
        "context": {
            "authenticated": effect == "Allow",
        },
    }


def lambda_handler(event: dict, context: object) -> dict:
    del context

    method_arn = event.get("methodArn", "*")
    supplied_token = _get_bearer_token(event)

    if supplied_token is None:
        return _policy("Deny", method_arn)

    try:
        expected_token = _get_expected_token()
    except BotoCoreError, ClientError, RuntimeError:
        return _policy("Deny", method_arn)

    effect = "Allow" if hmac.compare_digest(supplied_token, expected_token) else "Deny"

    return _policy(effect, method_arn)
