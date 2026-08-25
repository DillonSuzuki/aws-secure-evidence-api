output "evidence_bucket_name" {
  description = "Name of the encrypted evidence bucket."
  value       = aws_s3_bucket.evidence.id
}

output "findings_table_name" {
  description = "Name of the encrypted findings table."
  value       = aws_dynamodb_table.findings.name
}

output "kms_key_arn" {
  description = "ARN of the customer-managed encryption key."
  value       = aws_kms_key.project.arn
}