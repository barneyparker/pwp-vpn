variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type for the VPN server"
  type        = string
  default     = "t4g.micro"
}

variable "instance_name" {
  description = "Name tag for the VPN server instance"
  type        = string
  default     = "pwp-vpn-server"
}

variable "spot_price_max" {
  description = "Maximum spot price for the VPN server instance"
  type        = string
  default     = "0.0084" # Adjust based on instance type and region
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
  default     = null # "arn:aws:kms:eu-west-2:157651656631:key/f7d244a8-27af-40f6-b908-94f7d4017263" # null if not using KMS encryption
}

variable "schedule_timezone" {
  description = "Timezone for VPN server scheduling (scale up/down times)"
  type        = string
  default     = "GMT"
}

variable "default_tags" {
  default = {
    Repository = "pwp-vpn"
    Stack      = "root"
  }
}

variable "root_domain" {
  description = "Root DNS domain to use for API records"
  type        = string
  default     = "barneyparker.com"
}