# CloudWatch alarms for security monitoring
resource "aws_cloudwatch_log_metric_filter" "failed_logins" {
  name           = "pwp-failed-login-attempts"
  log_group_name = "/aws/lambda/pwp-asg-api"
  pattern        = "[timestamp, requestId, level=\"WARN\", message=\"LOGIN_FAILED\", ...]"

  metric_transformation {
    name      = "FailedLoginAttempts"
    namespace = "PWP/Security"
    value     = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "high_failed_logins" {
  alarm_name          = "pwp-high-failed-login-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FailedLoginAttempts"
  namespace           = "PWP/Security"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "High number of failed login attempts detected"
  alarm_actions       = [] # Add SNS topic ARN here if you want notifications

  treat_missing_data = "notBreaching"
}

# Metric filter for WAF blocks
resource "aws_cloudwatch_log_metric_filter" "waf_blocks" {
  name           = "pwp-waf-blocks"
  log_group_name = aws_cloudwatch_log_group.waf_logs.name
  pattern        = "[timestamp, requestId, ..., action=\"BLOCK\", ...]"

  metric_transformation {
    name      = "WAFBlocks"
    namespace = "PWP/Security"
    value     = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_blocks_alarm" {
  alarm_name          = "pwp-waf-blocks-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "WAFBlocks"
  namespace           = "PWP/Security"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "WAF has blocked suspicious requests"
  alarm_actions       = [] # Add SNS topic ARN here if you want notifications

  treat_missing_data = "notBreaching"
}