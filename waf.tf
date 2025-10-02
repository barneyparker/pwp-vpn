# WAF v2 Web ACL for rate limiting on API Gateway
resource "aws_wafv2_web_acl" "api_rate_limit" {
  name  = "pwp-api-rate-limit"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate-based rule to block IPs that exceed login attempt threshold
  rule {
    name     = "LoginRateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 10  # 10 requests per 5-minute window
        aggregate_key_type = "IP"
        
        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                search_string = "POST"
                field_to_match {
                  method {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
                positional_constraint = "EXACTLY"
              }
            }
            statement {
              byte_match_statement {
                search_string = "username="
                field_to_match {
                  body {
                    oversize_handling = "CONTINUE"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "URL_DECODE"
                }
                positional_constraint = "CONTAINS"
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LoginRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # More aggressive rate limiting for potential attack patterns
  rule {
    name     = "AggressiveRateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 50  # 50 requests per 5-minute window from same IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AggressiveRateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "PWPAPIRateLimit"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_waf_association" {
  resource_arn = aws_apigatewayv2_stage.default_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.api_rate_limit.arn
}

# CloudWatch Log Group for WAF logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/wafv2/pwp-api-rate-limit"
  retention_in_days = 30
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "api_waf_logging" {
  resource_arn            = aws_wafv2_web_acl.api_rate_limit.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    body {
      oversize_handling = "CONTINUE"
    }
  }
}