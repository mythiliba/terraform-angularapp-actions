terraform {
  backend "s3" {
    bucket         = "angular-app-tfstate"
    key            = "LockID"
    region         = "us-east-2"
    dynamodb_table = "hello-world-state-locks"
      }
}
