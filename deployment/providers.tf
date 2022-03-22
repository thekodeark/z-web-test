terraform {
  required_providers {
    aws = "~> 3.40.0"
  }
}

provider "aws" {
  region = var.region
}

data "aws_region" "active" {}

data "aws_caller_identity" "active" {}
