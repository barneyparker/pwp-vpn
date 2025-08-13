# PWP-VPN

A cost-effective VPN server that allows access to the internet via another country, built with AWS infrastructure.

## Features

- **Cost Optimized**: Uses t4g.nano spot instances with auto-scaling (scales down at night)
- **Secure**: Certificate-based OpenVPN with TLS encryption
- **Persistent**: Certificates and configurations stored in encrypted S3 bucket
- **Flexible**: Supports both UDP (primary) and TCP (fallback) protocols
- **Automated**: Fully automated setup and configuration via Terraform

## Infrastructure

- **Instance**: t4g.nano spot instance (ARM64) with Amazon Linux 2023
- **Networking**: Custom VPC (10.0.0.0/28) with public subnet
- **Storage**: S3 bucket for certificates and client configurations
- **Scaling**: Auto Scaling Group that scales down at 23:00 GMT, up at 07:00 GMT
- **Protocols**: OpenVPN on UDP 1194 (primary) and TCP 443 (fallback)

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version ~> 1.12)
- An AWS account with permissions to create VPC, EC2, S3, and IAM resources

## Deployment

1. **Clone and setup**:

   ```bash
   cd pwp-vpn
   ```

2. **Configure region** (optional):
   Edit `variables.tf` to change the default region from `eu-west-2`

3. **Deploy infrastructure**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Wait for setup**: The instance will take 5-10 minutes to configure OpenVPN and generate certificates.

## Usage

### Download Client Configuration

Use the provided script to download your VPN configuration:

```bash
./get-client-config.sh
```

This will download:

- `client.ovpn` - UDP configuration (recommended)
- `client-tcp.ovpn` - TCP configuration (fallback)

### Connect to VPN

1. Install an OpenVPN client on your device
2. Import the downloaded `.ovpn` file
3. Connect to the VPN

### Manual Download

You can also manually download configurations from S3:

```bash
# Get bucket name
BUCKET=$(terraform output -raw vpn_bucket_name)

# Download configurations
aws s3 cp s3://$BUCKET/client.ovpn ./client.ovpn
aws s3 cp s3://$BUCKET/client-tcp.ovpn ./client-tcp.ovpn
```

## Monitoring

Check the status of your VPN infrastructure:

```bash
# Get current server IP
terraform output vpn_server_ip

# Check if instance is running
aws ec2 describe-instances --filters "Name=tag:Name,Values=pwp-vpn-server" "Name=instance-state-name,Values=running"
```

## Cost Management

- **Automatic Scaling**: Server automatically shuts down at 23:00 GMT and starts at 07:00 GMT
- **Spot Instances**: Uses spot instances to minimize costs
- **Minimal Resources**: Uses the smallest instance type (t4g.nano) and minimal network infrastructure

## Security

- **No SSH Access**: No SSH keys or SSH access configured
- **Certificate-based Auth**: Uses PKI certificates for authentication
- **Encrypted Storage**: All certificates encrypted in S3
- **Network Isolation**: Instance can only access internet and S3
- **Minimal Permissions**: IAM roles follow least privilege principle

## Troubleshooting

### VPN Won't Connect

- Check if the instance is running (may be scaled down between 23:00-07:00 GMT)
- Try the TCP configuration if UDP doesn't work
- Verify your local firewall allows OpenVPN traffic

### Server Not Starting

- Check Auto Scaling Group status in AWS console
- Review instance logs in EC2 console
- Ensure your AWS account has sufficient limits

### Certificate Issues

- Certificates are automatically generated on first boot
- If needed, delete S3 bucket contents to force regeneration

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

Note: This will delete all certificates and configurations permanently.

## Architecture

```
Internet
    |
Internet Gateway
    |
Public Subnet (10.0.1.0/28)
    |
t4g.nano Instance (OpenVPN)
    |
S3 Bucket (Certificates & Configs)
```

## License

This project is for personal use. Ensure compliance with your local laws regarding VPN usage.
