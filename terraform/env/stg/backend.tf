terraform {
  backend "s3" {
    bucket         = "ajay-tf-state-inspired"
    key            = "stg/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}
