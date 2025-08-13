terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    region       = "eu-west-1"
    bucket       = "pwp-tfstate"
    key          = "pwp-vpn.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::562311163954:role/DeploymentRole"
  }
  default_tags {
    tags = var.default_tags
  }
}

provider "aws" {
  alias  = "dns"
  region = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::610879547730:role/core_dns"
  }

  default_tags {
    tags = var.default_tags
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available_for_outputs" {
  state = "available"
}


data "aws_route53_zone" "domain" {
  provider = aws.dns
  name     = var.root_domain
}