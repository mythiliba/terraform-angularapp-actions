
resource "aws_s3_bucket" "terraform_state" {
  bucket = "hello-world-terraform-state"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }

  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }

}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "hello-world-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}