terraform {
  aws = {
     source = "hashicorp/aws"
   }
 }
 backend "s3" {
   bucket = "angular-app"
   region = "us-east-2"
   key    = "sample/terraform.tfstate"
   dynamodb_table = "sample-application-terraform"
 }
}
