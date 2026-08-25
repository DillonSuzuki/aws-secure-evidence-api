import json
import uuid
from datetime import UTC, datetime

ALLOWED_SEVERITIES = {"low", "moderate", "high", "critical"}
REQUIRED_FIELDS = {"title", "severity", "description"}


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event: dict, context: object) -> dict:
    del context

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

    return _response(201, finding)
