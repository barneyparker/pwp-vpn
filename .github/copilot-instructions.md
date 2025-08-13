# PWP VPN

Create a VPN server to allow access to the internet

## Infrastructure Requirements

The server should be a t4g.nano instance in the region specified in the region variable.

The server should be part of an auto-scaling group with a maximum size of 1.

The server should be in a public subnet with a public IP address and must not use a NAT gateway.

The server should use an AWS provided AMI for the t4g.nano instance type.

The server should configure itself using user-data to install and configure OpenVPN.

Any assets required to be persistent between server restarts should be stored in an S3 bucket.

The auto-scaling group should be scheduled to scale to 0 at 11pm GMT, and scale back to 1 at 7am GMT.

The IP address of the OpenVPN server should be output from Terraform. In the future this will be a real DNS entry, but for now we will use the ip address of the server.

No ssh keys should be created or used, and no ssh access should be allowed to the server.

The server should only be able to route traffic to the internet, and not to any other AWS resources.

We should use spot instances to keep costs to a minimum

do not apply tags on resources, this is doe at the provider level

## Networking Configuration

### VPC and Subnets

- Create a new VPC with CIDR block 10.0.0.0/28
- Create a public subnet with CIDR block 10.0.1.0/28
  Only 1 AZ is required
- Attach an Internet Gateway to the VPC
- Configure route table to route 0.0.0.0/0 traffic through the Internet Gateway

### Security Groups

- Allow inbound UDP traffic on port 1194 (OpenVPN) from 0.0.0.0/0
- Allow inbound TCP traffic on port 443 (OpenVPN over HTTPS) from 0.0.0.0/0
- Allow all outbound traffic to 0.0.0.0/0
- Deny all other inbound traffic (including SSH on port 22)

## OpenVPN Configuration

### Network Settings

- Use routing mode (not bridging)
- Client IP pool: 10.8.0.0/24
- Push DNS servers: 1.1.1.1 and 8.8.8.8
- Enable IP forwarding and NAT masquerading
- Use UDP protocol on port 1194 as primary, TCP 443 as fallback

### Certificate Management

- Generate Certificate Authority (CA) using Easy-RSA
- Create server certificate and key
- Generate Diffie-Hellman parameters (2048-bit minimum)
- Store all certificates and keys in S3 bucket with encryption
- Implement certificate rotation strategy (annual renewal)

### Authentication

- Use certificate-based authentication
- Generate client certificates on-demand
- Store client configurations in S3 bucket
- Provide secure method to distribute .ovpn files to clients

## S3 Storage Configuration

### Bucket Setup

- Bucket name: pwp-vpn-{random-suffix}
- Enable server-side encryption with AES-256
- Enable versioning for certificate backup
- Block all public access
- Use Standard storage class for frequently accessed files
- Use Standard-IA for backup and historical data

### Stored Assets

- OpenVPN server certificates and keys
- Certificate Authority (CA) files
- Diffie-Hellman parameters
- Server configuration templates
- Client certificate templates
- Generated client .ovpn configuration files

## IAM Configuration

### EC2 Instance Profile

- Create IAM role for EC2 instance
- Attach policy allowing:
  - s3:GetObject and s3:PutObject on the VPN bucket
  - s3:ListBucket on the VPN bucket
  - logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents for CloudWatch

### Minimal Permissions

- Instance should not have access to any other AWS resources
- Use least privilege principle
- No cross-account access

## Auto Scaling Configuration

### Health Checks

- Use EC2 health checks
- Health check grace period: 300 seconds
- Unhealthy threshold: 2 consecutive failures

### Scaling Schedule

- Scale down to 0 instances at 23:00 GMT daily
- Scale up to 1 instance at 07:00 GMT daily
- Use scheduled scaling actions
- Set desired capacity, min size (0), max size (1)

## Monitoring and Logging

### Logging

No logging is required

### Health Monitoring

- Monitor instance health via Auto Scaling Group
- Track VPN connection metrics
- Alert on repeated health check failures

## Security Considerations

### Network Isolation

- Instance can only communicate with:
  - Internet (for VPN traffic routing)
  - S3 (for certificate storage)
- No access to other VPC resources or AWS services
- Server IP address must not change between scaling up & down events

### Data Protection

- All certificates encrypted at rest in S3
- TLS encryption for all OpenVPN traffic
- Regular security updates via user-data script
- Run OS updates via user-data script on instance startup

## Outputs and Client Access

### Terraform Outputs

- Output the public IP address of the VPN server
- Output the S3 bucket name for client configuration retrieval
- Output connection instructions

### Client Onboarding

- Only one user is required, so no user management is needed
- Provide client with .ovpn file containing:
  - Server IP address
  - CA certificate
  - Client certificate and key

## Testing and Validation

### Manual Verification

- Test client connection from different networks
- Verify IP address changes when connected
- Confirm DNS leak protection
- Test reconnection after server restart
