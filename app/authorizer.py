from app import authentication


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
    effect = "Allow" if authentication.is_authorized(event) else "Deny"

    return _policy(effect, method_arn)
