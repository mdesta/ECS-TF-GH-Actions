# S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
  # The s3 bucket name needs to be globally unique, so add company name there
  bucket = "mdesta-${var.environment_name}-terraform"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

}

resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB
resource "aws_dynamodb_table" "terraform_statelock" {
  name         = "${var.environment_name}-terraform"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

}
