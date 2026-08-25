locals {
  common_tags = {
    Project            = var.project_name
    Environment        = "local"
    ManagedBy          = "OpenTofu"
    DataClassification = "Sensitive"
  }
}

resource "aws_kms_key" "project" {
  description             = "Encryption key for ${var.project_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "project" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.project.key_id
}

resource "aws_s3_bucket" "evidence" {
  bucket = "${var.project_name}-evidence"

  tags = merge(local.common_tags, {
    Purpose = "Security evidence storage"
  })
}

resource "aws_s3_bucket_ownership_controls" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.project.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "findings" {
  name         = "${var.project_name}-findings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "findingId"

  attribute {
    name = "findingId"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.project.arn
  }

  tags = merge(local.common_tags, {
    Purpose = "Security finding metadata"
  })
}