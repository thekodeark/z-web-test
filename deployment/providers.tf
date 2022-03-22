terraform {
  required_providers {
    aws = "~> 3.40.0"
  }
  backend "remote" {
    organization = "KodeArkAdmin"
    workspaces {
      prefix = "z-infra-"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_region" "active" {}

data "aws_caller_identity" "active" {}
