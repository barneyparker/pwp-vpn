# S3 Bucket for VPN assets
resource "aws_s3_bucket" "vpn_bucket" {
  bucket_prefix = "pwp-vpn-"
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "vpn_bucket_versioning" {
  bucket = aws_s3_bucket.vpn_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_bucket_encryption" {
  bucket = aws_s3_bucket.vpn_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "vpn_bucket_pab" {
  bucket = aws_s3_bucket.vpn_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload the rendered script to S3
resource "aws_s3_object" "vpn_idle_shutdown" {
  bucket = aws_s3_bucket.vpn_bucket.id
  key    = "vpn-idle-shutdown.sh"
  content = templatefile("${path.module}/vpn-idle-shutdown.sh", {
    region   = var.region
    asg_name = aws_autoscaling_group.vpn_asg.name
  })
  server_side_encryption = "AES256"
}