terraform {
  backend "s3" {
    bucket         = "angular-app-tfstate"
    key            = "LockID"
    region         = "us-east-1"
    dynamodb_table = "hello-world-state-locks"
      }
}
