terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    key     = "prod/terraform.tfstate"
    # Overridden at runtime by -backend-config="region=..." in the workflow.
    region  = "eu-west-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
