# NIST SP 800-53 Control Mapping

## Scope

This document maps security mechanisms demonstrated by the AWS Secure Evidence
API to relevant NIST SP 800-53 Revision 5 controls.

The project runs in LocalStack for development and portfolio demonstration.
These mappings show how technical mechanisms support control objectives; they
do not represent a complete control implementation, FedRAMP compliance, or an
authorization to operate.

## Current Control Mapping

| Control | Technical implementation | Verification evidence | Status |
|---|---|---|---|
| AC-3 – Access Enforcement | S3 public access is blocked, ACL-based ownership is disabled, and bucket ownership is enforced. | `get-public-access-block` and `get-bucket-ownership-controls` | Demonstrated locally |
| CM-2 – Baseline Configuration | OpenTofu defines the KMS key, S3 bucket, DynamoDB table, encryption, versioning, and access settings. | `tofu validate` and a no-change `tofu plan` | Demonstrated locally |
| CM-3 – Configuration Change Control | Infrastructure changes are developed on a Git feature branch and reviewed through an OpenTofu execution plan before application. | Git history and OpenTofu plan output | Partially demonstrated |
| SA-10 – Developer Configuration Management | Application and infrastructure configuration are maintained in source control with provider-version locking. | Git history and `.terraform.lock.hcl` | Demonstrated locally |
| SC-12 – Cryptographic Key Establishment and Management | A customer-managed KMS key and alias are defined through OpenTofu with annual automatic rotation. | `describe-key` and `get-key-rotation-status` | Demonstrated locally |
| SC-13 – Cryptographic Protection | KMS cryptography protects evidence objects and finding metadata. | S3 and DynamoDB encryption inspection | Demonstrated locally |
| SC-28 – Protection of Information at Rest | S3 and DynamoDB use the project KMS key for server-side encryption. | `get-bucket-encryption` and `describe-table` | Demonstrated locally |

## Additional Security Mechanisms

- S3 versioning preserves previous object versions.
- S3 Bucket Keys reduce direct KMS request volume.
- Customer-provided S3 encryption keys are blocked.
- DynamoDB uses on-demand capacity to avoid unnecessary local capacity configuration.

## Limitations

- LocalStack emulates AWS services but does not prove identical production AWS behavior.
- LocalStack Hobby does not provide every production security capability.
- Runtime IAM-policy enforcement and full audit logging are not demonstrated yet.
- This project is NIST/FedRAMP-aligned for learning purposes and is not a FedRAMP-authorized system.