# NIST SP 800-53 Control Mapping

## Scope

This document maps security mechanisms demonstrated by the AWS Secure Evidence
API to relevant NIST SP 800-53 Revision 5 controls.

The project runs in LocalStack for development and portfolio demonstration.
These mappings show how technical mechanisms support control objectives; they
do not represent complete control implementations, FedRAMP compliance, or an
authorization to operate.

## Current Control Mapping

| Control | Technical implementation | Verification evidence | Status |
|---|---|---|---|
| AC-3 – Access Enforcement | S3 public access is blocked, ACL-based ownership is disabled, and bucket ownership is enforced. | `get-public-access-block` and `get-bucket-ownership-controls` | Demonstrated locally |
| AC-6 - Least Privilege | The Lambda execution role permits only `dynamodb:PutItem` on the findings table and log writes to its own log group. API Gateway may invoke Lambda only through the scoped `POST /findings` source ARN. | `get-role-policy`, Lambda permission configuration, and OpenTofu plan | Configured locally |
| AU-2 - Event Logging | API Gateway access logging is configured for request outcomes, while Lambda generates function execution records. | OpenTofu configuration, `get-stage`, and CloudWatch log-group inspection | Partially demonstrated |
| AU-3 - Content of Audit Records | The structured API log format includes request ID, time, source IP, user agent, method, resource path, status, response size, and latency. Request and response bodies are excluded. | Stage configuration and `data_trace_enabled = false` | Configured locally; delivery not demonstrated |
| AU-9 - Protection of Audit Information | A dedicated API Gateway role can discover log groups and write only to the project access-log group. It cannot read, modify, or delete audit records. | `get-role-policy` | Configured locally |
| AU-11 - Audit Record Retention | Lambda and API access-log groups have an explicit 14-day retention period. | `describe-log-groups` | Configured locally |
| AU-12 - Audit Record Generation | Lambda generates execution records with request IDs and execution statistics. API Gateway access logging is configured to generate structured request records. | Lambda `logs tail`, API Gateway configuration, and access-log delivery test | Partially demonstrated |
| CM-2 - Baseline Configuration | OpenTofu defines the KMS key, S3 bucket, DynamoDB table, Lambda, IAM role, API Gateway route, request validator, deployment, encryption, versioning, and access settings. | `tofu validate` and a no-change `tofu plan` | Demonstrated locally |
| CM-3 – Configuration Change Control | Changes are developed on Git feature branches, reviewed through OpenTofu plans, and merged through pull requests. | Git history and pull-request history | Demonstrated |
| SA-10 – Developer Configuration Management | Application and infrastructure configuration are maintained in source control with provider-version locking. | Git history and `.terraform.lock.hcl` | Demonstrated |
| SA-11 - Developer Testing and Evaluation | Automated unit tests and API-level positive and negative tests evaluate validation, error handling, and persistence behavior. | Five passing unit tests, successful API submission, HTTP `400` validation response, and DynamoDB verification | Demonstrated locally |
| SC-5 - Denial-of-Service Protection | The `POST /findings` method is configured for 2 requests per second with a burst limit of 5. | `get-stage` and a 20-request concurrent test | Configured; not enforced by LocalStack |
| SC-12 – Cryptographic Key Establishment and Management | A customer-managed KMS key and alias are defined through OpenTofu with annual automatic rotation. | `describe-key` and `get-key-rotation-status` | Demonstrated locally |
| SC-13 – Cryptographic Protection | KMS cryptography protects evidence objects and finding metadata. | S3 and DynamoDB encryption inspection | Demonstrated locally |
| SC-28 – Protection of Information at Rest | S3 and DynamoDB use the project KMS key for server-side encryption. | `get-bucket-encryption` and `describe-table` | Demonstrated locally |
| SI-10 - Information Input Validation | API Gateway validates request bodies against a JSON schema before invocation. Lambda independently rejects invalid JSON, missing or empty fields, and unauthorized severity values before persistence. | HTTP `400` negative test, unchanged DynamoDB item count, and automated unit tests | Demonstrated |
| SI-11 – Error Handling | Persistence failures produce a generic client response while detailed exceptions remain in controlled function logs. | Automated unit test for simulated persistence failure | Demonstrated |

## Additional Security Mechanisms

- DynamoDB conditional writes prevent an existing finding ID from being overwritten.
- S3 versioning preserves previous object versions.
- S3 Bucket Keys reduce direct KMS request volume.
- Customer-provided S3 encryption keys are blocked.
- Lambda configuration uses a supported Python runtime, a 10-second timeout,
  and a dedicated execution role.
- CloudWatch logs use a defined 14-day retention period.
- DynamoDB uses on-demand capacity to avoid unnecessary capacity configuration.
- API Gateway rejects requests that do not satisfy the finding JSON schema before Lambda invocation.
- Lambda performs a second layer of application-level validation.
- API Gateway's Lambda invocation permission is scoped to the 'POST /findings' route.

## API Observability Verification

- API Gateway is associated with a dedicated CloudWatch logging role.
- The access-log group exists with a 14-day retention period.
- The logging policy permits stream creation and event writes only within the
  project access-log group.
- Detailed metrics are enabled for `POST /findings`.
- Data tracing is disabled to prevent finding contents from being copied into
  API execution logs.
- Method throttling is configured for 2 requests per second with a burst of 5.
- A successful request created no API access-log stream in LocalStack.
- Twenty concurrent invalid requests all returned HTTP 400 rather than HTTP 429.
- The load test did not change the DynamoDB item count.

These results distinguish controls that are configured from controls whose
runtime effectiveness can be demonstrated in the local emulator.

## Limitations

- LocalStack emulates AWS services but does not prove identical production AWS behavior.
- LocalStack Hobby does not enforce IAM policies at runtime, so the least-privilege
  policy can be inspected but its denial behavior is not demonstrated.
- CloudTrail and complete production audit logging are not demonstrated.
- The API endpoint currently has no authentication or authorization, so any caller able to reach the local endpoint can submit a finding.
- API Gateway access logging and request throttling have not yet been implemented.
- AWS provider version 6.56.0 is intentionally pinned because later provider version expect an API Gateway availability status that LocalStack does not currently return.
- Lambda currently uses the runtime-provided Boto3 SDK; production dependency
  packaging and vulnerability scanning will be addressed separately.
- This project is NIST/FedRAMP-aligned for learning purposes and is not a
  FedRAMP-authorized system.
  - LocalStack accepted the API access-log configuration but returned no stage
  access-log settings and created no log stream during runtime testing.
- LocalStack accepted method-level throttling settings but did not enforce them
  during a 20-request concurrent test.
- API Gateway detailed metrics are configured, but metric emission has not been
  operationally demonstrated in LocalStack.