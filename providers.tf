terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "lead-de-global-tfstate-bucket" # Must be globally unique, change 'yourname'
    key            = "data-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }

}

provider "aws" {
  region = "us-east-1"
}
