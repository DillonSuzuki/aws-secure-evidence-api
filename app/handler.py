import json
import logging
import os
import uuid
from datetime import UTC, datetime

import boto3

from app import authentication

ALLOWED_SEVERITIES = {"low", "moderate", "high", "critical"}
REQUIRED_FIELDS = {"title", "severity", "description"}

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _persist_finding(finding: dict[str, str]) -> None:
    table_name = os.environ.get("FINDINGS_TABLE_NAME")

    if not table_name:
        raise RuntimeError("FINDINGS_TABLE_NAME is not configured.")

    table = boto3.resource("dynamodb").Table(table_name)
    table.put_item(
        Item=finding,
        ConditionExpression="attribute_not_exists(findingId)",
    )


def lambda_handler(event: dict, context: object) -> dict:
    del context

    if not authentication.is_authorized(event):
        return _response(403, {"message": "Forbidden."})

    raw_body = event.get("body")

    if raw_body is None:
        return _response(400, {"message": "Request body is required."})

    try:
        body = json.loads(raw_body) if isinstance(raw_body, str) else raw_body
    except json.JSONDecodeError:
        return _response(400, {"message": "Request body must be valid JSON."})

    if not isinstance(body, dict):
        return _response(400, {"message": "Request body must be a JSON object."})

    missing_fields = sorted(
        field
        for field in REQUIRED_FIELDS
        if not isinstance(body.get(field), str) or not body[field].strip()
    )

    if missing_fields:
        return _response(
            400,
            {
                "message": "Required fields are missing or empty.",
                "fields": missing_fields,
            },
        )

    severity = body["severity"].strip().lower()

    if severity not in ALLOWED_SEVERITIES:
        return _response(
            400,
            {
                "message": "Severity is invalid.",
                "allowedValues": sorted(ALLOWED_SEVERITIES),
            },
        )

    finding = {
        "findingId": str(uuid.uuid4()),
        "title": body["title"].strip(),
        "severity": severity,
        "description": body["description"].strip(),
        "createdAt": datetime.now(UTC).isoformat(),
        "status": "open",
    }

    try:
        _persist_finding(finding)
    except Exception:
        LOGGER.exception(
            "Unable to persist finding.",
            extra={"findingId": finding["findingId"]},
        )
        return _response(500, {"message": "Finding could not be stored."})

    return _response(201, finding)
