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
| AC-3 - Access Enforcement | S3 public access is blocked and bucket ownership is enforced. The findings API uses an API Gateway REQUEST authorizer and an independent fail-closed authorization check in the ingest Lambda. | S3 configuration inspection, direct authorizer tests, automated tests, HTTP `403/403/201` results, and DynamoDB item counts | S3 and application-layer enforcement demonstrated; API Gateway authorizer enforcement not demonstrated in LocalStack |
| AC-6 - Least Privilege | The ingest Lambda can write only to the findings table, read only the API authorizer secret, decrypt only with the project KMS key through Secrets Manager, and write only to its own log group. The authorizer Lambda has similarly scoped secret, KMS, and logging permissions. API Gateway invocation permissions are scoped to the intended API resources. | `get-role-policy`, Lambda permission configuration, and OpenTofu plan | Configured locally; runtime IAM denial behavior not demonstrated |
| AU-2 - Event Logging | API Gateway access logging is configured for request outcomes, while Lambda generates function execution records. | OpenTofu configuration, `get-stage`, and CloudWatch log-group inspection | Partially demonstrated |
| AU-3 - Content of Audit Records | The structured API log format includes request ID, time, source IP, user agent, method, resource path, status, response size, and latency. Request and response bodies are excluded. | Stage configuration and `data_trace_enabled = false` | Configured locally; delivery not demonstrated |
| AU-9 - Protection of Audit Information | A dedicated API Gateway role can discover log groups and write only to the project access-log group. It cannot read, modify, or delete audit records. | `get-role-policy` | Configured locally |
| AU-11 - Audit Record Retention | Lambda and API access-log groups have an explicit 14-day retention period. | `describe-log-groups` | Configured locally |
| AU-12 - Audit Record Generation | Lambda generates execution records with request IDs and execution statistics. API Gateway access logging is configured to generate structured request records. | Lambda `logs tail`, API Gateway configuration, and access-log delivery test | Partially demonstrated |
| CM-2 - Baseline Configuration | OpenTofu defines the KMS key, S3 bucket, DynamoDB table, Lambda functions, IAM roles, Secrets Manager secret metadata, API Gateway route, authorizer, request validator, deployment, logging, encryption, versioning, and access settings. | `tofu validate` and a no-change `tofu plan` | Demonstrated locally |
| CM-3 - Configuration Change Control | Changes are developed on Git feature branches, reviewed through OpenTofu plans, and merged through pull requests. | Git history and pull-request history | Demonstrated |
| IA-5 - Authenticator Management | A randomly generated bearer token is stored in Secrets Manager, encrypted with the project KMS key, and excluded from source code and OpenTofu configuration. Authentication uses constant-time token comparison and fails closed when the secret is unavailable. | Secrets Manager metadata, IAM policy inspection, application code, and automated tests | Partially demonstrated for a shared service token |
| SA-10 - Developer Configuration Management | Application and infrastructure configuration are maintained in source control with provider-version locking. | Git history and `.terraform.lock.hcl` | Demonstrated |
| SA-11 - Developer Testing and Evaluation | Thirteen automated tests evaluate authentication, authorization failure, input validation, error handling, and persistence behavior. API-level tests verify missing, invalid, and valid bearer-token outcomes. | Thirteen passing tests, HTTP `403/403/201` results, and DynamoDB count verification | Demonstrated locally |
| SC-5 - Denial-of-Service Protection | The `POST /findings` method is configured for 2 requests per second with a burst limit of 5. | `get-stage` and a 20-request concurrent test | Configured; not enforced by LocalStack |
| SC-12 - Cryptographic Key Establishment and Management | A customer-managed KMS key and alias are defined through OpenTofu with annual automatic rotation. The same key protects evidence, finding metadata, and the API authorizer secret. | `describe-key`, `get-key-rotation-status`, secret metadata, and resource encryption inspection | Demonstrated locally |
| SC-13 - Cryptographic Protection | KMS cryptography protects evidence objects, finding metadata, and the API authorizer secret. | S3, DynamoDB, KMS, and Secrets Manager inspection | Demonstrated locally |
| SC-28 - Protection of Information at Rest | S3, DynamoDB, and the Secrets Manager authorizer secret use the project KMS key for encryption at rest. | `get-bucket-encryption`, `describe-table`, and `describe-secret` | Demonstrated locally |
| SI-10 - Information Input Validation | API Gateway validates request bodies against a JSON schema. After authentication, Lambda independently rejects invalid JSON, missing or empty fields, and unauthorized severity values before persistence. | HTTP `400` negative test, unchanged DynamoDB item count, and automated tests | Demonstrated |
| SI-11 - Error Handling | Authentication failures return a generic `403` response, while persistence failures return a generic `500` response and detailed exceptions remain in controlled function logs. | Automated authentication and simulated persistence-failure tests | Demonstrated |

## Additional Security Mechanisms

- DynamoDB conditional writes prevent an existing finding ID from being overwritten.
- S3 versioning preserves previous object versions.
- S3 Bucket Keys reduce direct KMS request volume.
- Customer-provided S3 encryption keys are blocked.
- Lambda functions use supported Python runtimes, defined timeouts, and dedicated execution roles.
- CloudWatch log groups use a defined 14-day retention period.
- DynamoDB uses on-demand capacity to avoid unnecessary capacity configuration.
- API Gateway rejects requests that do not satisfy the finding JSON schema.
- Lambda performs independent authentication and input validation before persistence.
- API Gateway Lambda invocation permissions are scoped to their intended API resources.
- The bearer-token value is not stored in Git or OpenTofu configuration.
- The authorizer and ingest Lambda share one authentication implementation to avoid inconsistent authorization decisions.

## API Authorization Verification

The intended primary control is an API Gateway REQUEST Lambda authorizer. Direct
Lambda invocation demonstrated that the authorizer returns `Allow` for the valid
token and `Deny` for missing or invalid tokens.

LocalStack accepted the API Gateway authorizer configuration but did not invoke
or enforce it when requests used either the alternative execute-api route or the
hostname-based route. Requests without valid tokens initially reached the ingest
Lambda and were persisted.

A fail-closed authentication check was therefore added to the ingest Lambda as
a compensating application-layer control. End-to-end testing produced:

| Test | HTTP result | DynamoDB result |
|---|---:|---|
| Missing bearer token | `403` | Item count unchanged |
| Invalid bearer token | `403` | Item count unchanged |
| Valid bearer token | `201` | Item count increased by exactly one |

The DynamoDB item count remained `5` after both rejected requests and increased
to `6` only after the authorized request. Three misleading records created
during the failed API Gateway enforcement test were subsequently removed by
their exact finding IDs.

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
- LocalStack Hobby does not enforce IAM policies at runtime, so least-privilege
  policies can be inspected but their denial behavior is not demonstrated.
- LocalStack accepted the API Gateway custom-authorizer configuration but did
  not invoke or enforce it during end-to-end API testing.
- Application-layer bearer-token validation is implemented as a compensating
  control for the LocalStack authorizer-enforcement limitation.
- The shared bearer token authenticates a local API client but does not establish
  individual user identities, MFA, account lifecycle management, or complete
  IA-2 compliance.
- Cognito user pools are unavailable in the LocalStack Hobby license and were
  excluded rather than requiring a paid upgrade.
- LocalStack accepted the API access-log configuration but returned no stage
  access-log settings and created no log stream during runtime testing.
- LocalStack accepted method-level throttling settings but did not enforce them
  during a 20-request concurrent test.
- API Gateway detailed metrics are configured, but metric emission has not been
  operationally demonstrated in LocalStack.
- CloudTrail and complete production audit logging are not demonstrated.
- AWS provider version 6.56.0 is intentionally pinned because later provider
  versions expect an API Gateway availability status that LocalStack does not
  currently return.
- Lambda currently uses the runtime-provided Boto3 SDK; production dependency
  packaging and vulnerability scanning will be addressed separately.
- This project is NIST/FedRAMP-aligned for learning purposes and is not a
  FedRAMP-authorized system.