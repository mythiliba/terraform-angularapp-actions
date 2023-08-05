terraform {
 
 backend "s3" {
   bucket = "angular-app"
   region = "us-east-1"
   key    = "sample/terraform.tfstate"
   dynamodb_table = "sample-application-terraform"
 }
}
