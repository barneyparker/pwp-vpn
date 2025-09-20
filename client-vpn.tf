# AWS Client VPN Endpoint for direct internet access
resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "PWP VPN Client VPN Endpoint"
  server_certificate_arn = aws_acm_certificate.vpn_cert.arn
  client_cidr_block      = "10.10.0.0/16"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn_cert.arn
  }

  connection_log_options {
    enabled = false
  }

  dns_servers = ["8.8.8.8", "1.1.1.1"]

  split_tunnel = false

  tags = {
    Name = "pwp-vpn-client-endpoint"
  }
}

# Network Association - Associate with public subnet for internet access
resource "aws_ec2_client_vpn_network_association" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = aws_subnet.vpn_public_subnets[0].id
}

# Authorization rule for internet access
resource "aws_ec2_client_vpn_authorization_rule" "internet" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
  description            = "Allow internet access"
}

# Route for internet traffic
resource "aws_ec2_client_vpn_route" "internet" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_subnet.vpn_public_subnets[0].id
  description            = "Route to internet via IGW"

  depends_on = [ aws_ec2_client_vpn_network_association.main ]
}

# Output the Client VPN endpoint ID
output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "client_vpn_endpoint_dns_name" {
  description = "DNS name of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}