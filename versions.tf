
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0, < 4.0"
    }
    null = {
      source = "hashicorp/null"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.15"
}
