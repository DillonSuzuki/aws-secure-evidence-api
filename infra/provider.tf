provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = var.aws_region

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true

  endpoints {
    apigateway = "http://127.0.0.1:4566"
    dynamodb   = "http://127.0.0.1:4566"
    iam        = "http://127.0.0.1:4566"
    kms        = "http://127.0.0.1:4566"
    lambda     = "http://127.0.0.1:4566"
    logs       = "http://127.0.0.1:4566"
    s3         = "http://127.0.0.1:4566"
    s3control  = "http://localstack.test:4566"
    sts        = "http://127.0.0.1:4566"
  }
}