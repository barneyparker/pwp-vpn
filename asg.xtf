locals {
  architecture = can(regex("g\\.", var.instance_type)) ? "arm64" : "x86_64"
}

resource "aws_autoscaling_group" "vpn_asg" {
  name                      = "pwp-vpn"
  vpc_zone_identifier       = aws_subnet.vpn_public_subnets[*].id
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Use Launch Template instead of Launch Configuration
  launch_template {
    id      = aws_launch_template.vpn_lt.id
    version = "$Latest"
  }

  min_size         = 0
  max_size         = 1
  desired_capacity = 1

  # Tag instances with the configurable name
  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_launch_template" "vpn_lt" {
  name_prefix   = "pwp-vpn-lt-"
  description   = "Launch template for PWP VPN server"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.vpn_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.vpn_instance_profile.name
  }

  # EBS configuration
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp3"
      volume_size           = 8
      delete_on_termination = true
      encrypted             = var.ebs_kms_key_id != null
      kms_key_id            = var.ebs_kms_key_id
    }
  }

  # Spot instance configuration for cost optimization
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = var.spot_price_max
    }
  }

  # User data
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    bucket_name       = aws_s3_bucket.vpn_bucket.bucket
    region            = var.region
    instance_name     = var.instance_name
    eip_allocation_id = aws_eip.vpn_eip.id
  }))

  # Metadata options for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Enable detailed monitoring
  monitoring {
    enabled = true
  }

  # Tag specifications
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.instance_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.instance_name}-volume"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*"]
  }

  filter {
    name   = "architecture"
    values = [local.architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "vpn_sg" {
  name_prefix = "pwp-vpn-sg-"
  vpc_id      = aws_vpc.vpn_vpc.id

  # OpenVPN UDP
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenVPN UDP"
  }

  # OpenVPN TCP (fallback)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenVPN TCP"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
}

resource "aws_iam_role" "vpn_instance_role" {
  name_prefix        = "pwp-vpn-instance-role-"
  assume_role_policy = data.aws_iam_policy_document.vpn_instance_role_assume.json
}

data "aws_iam_policy_document" "vpn_instance_role_assume" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpn_instance_role" {
  name   = "pwp-vpn"
  role   = aws_iam_role.vpn_instance_role.id
  policy = data.aws_iam_policy_document.vpn_instance_role.json
}

data "aws_iam_policy_document" "vpn_instance_role" {
  statement {
    sid = "S3ObjectAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.vpn_bucket.arn}/*"
    ]
  }

  statement {
    sid = "S3BucketAccess"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.vpn_bucket.arn
    ]
  }
  statement {
    sid = "ASGAccess"
    actions = [
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = [
      aws_autoscaling_group.vpn_asg.arn
    ]
  }

  statement {
    sid = "SSMParameterAccess"
    actions = [
      "ssm:PutParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/pwp-vpn/last-ready"
    ]
  }

  statement {
    sid = "SSMAccess"
    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.ebs_kms_key_id != null ? [var.ebs_kms_key_id] : []
    content {
      sid = "KMSAccess"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      resources = [statement.value]
    }
  }

  statement {
    sid = "SSMMessagesAccess"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2MessagesAccess"
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2EIPAccess"
    actions = [
      "ec2:DescribeAddresses",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
    ]
    resources = ["*"]
  }
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "vpn_instance_profile" {
  name_prefix = "pwp-vpn-instance-profile-"
  role        = aws_iam_role.vpn_instance_role.name
}

resource "aws_autoscaling_schedule" "vpn_scale_down" {
  scheduled_action_name  = "pwp-vpn-scale-down"
  min_size               = 0
  max_size               = 1
  desired_capacity       = 0
  recurrence             = "0 23 * * *"
  time_zone              = var.schedule_timezone
  autoscaling_group_name = aws_autoscaling_group.vpn_asg.name
}

resource "aws_kms_grant" "ec2_asg_service_linked" {
  count = var.ebs_kms_key_id != null ? 1 : 0

  name              = "pwp-vpn-autoscaling-ebs-grant"
  key_id            = var.ebs_kms_key_id
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant"
  ]
}
