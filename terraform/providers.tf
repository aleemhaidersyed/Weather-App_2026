# Configure the Terraform core requirements
terraform {
  required_version = ">= 1.5.0" # Ensures we are using a modern version of Terraform

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use the major version 5 provider to avoid breaking changes
    }
  }
}

# Configure the AWS Provider and define the target region
provider "aws" {
  region = var.aws_region
}