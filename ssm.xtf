resource "aws_ssm_parameter" "vpn_last_ready" {
  name        = "/pwp-vpn/last-ready"
  type        = "String"
  value       = "never"
  description = "Last time the VPN instance completed user-data and became ready."
  overwrite   = true
  lifecycle {
    ignore_changes = [value]
  }
}
