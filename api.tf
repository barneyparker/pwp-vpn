resource "aws_iam_role" "lambda_exec" {
  name_prefix = "pwp-vpn-lambda-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_basic" {
  role   = aws_iam_role.lambda_exec.name
  policy = data.aws_iam_policy_document.lambda_basic.json
}

data "aws_iam_policy_document" "lambda_basic" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:SetDesiredCapacity",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:GetParameter",
    ]
    resources = [aws_ssm_parameter.vpn_last_ready.arn]
  }
}

resource "archive_file" "asg_api" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/src.zip"
}
resource "aws_lambda_function" "asg_api" {
  function_name    = "pwp-asg-api"
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = archive_file.asg_api.output_path
  source_code_hash = archive_file.asg_api.output_sha256
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.vpn_asg.name
    }
  }
}

resource "aws_apigatewayv2_api" "asg_api" {
  name          = "pwp-asg-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "asg_integration" {
  api_id                 = aws_apigatewayv2_api.asg_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.asg_api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.asg_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.asg_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.asg_api.id
  name        = "$default"
  auto_deploy = true

  # Add throttling configuration as backup rate limiting
  throttle_settings {
    rate_limit  = 100  # 100 requests per second
    burst_limit = 200  # 200 burst capacity
  }

  # Enable access logging for security monitoring
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      status        = "$context.status"
      error         = "$context.error.message"
      responseTime  = "$context.responseTime"
      userAgent     = "$context.identity.userAgent"
    })
  }
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/pwp-asg-api"
  retention_in_days = 14
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asg_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.asg_api.execution_arn}/*/*"
}

# IAM role for API Gateway to write logs to CloudWatch
resource "aws_iam_role" "apigateway_cloudwatch" {
  name_prefix = "pwp-apigateway-cloudwatch-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for API Gateway CloudWatch logging
resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch" {
  role       = aws_iam_role.apigateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set the IAM role for API Gateway account settings
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch.arn
}

resource "aws_apigatewayv2_domain_name" "vpn_custom" {
  domain_name = "vpn.barneyparker.com"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.vpn_cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "vpn_mapping" {
  api_id      = aws_apigatewayv2_api.asg_api.id
  domain_name = aws_apigatewayv2_domain_name.vpn_custom.id
  stage       = aws_apigatewayv2_stage.default_stage.id
}

resource "aws_route53_record" "vpn_custom" {
  provider = aws.dns

  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "vpn"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.vpn_custom.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.vpn_custom.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "vpn_cert" {
  domain_name       = "vpn.barneyparker.com"
  validation_method = "DNS"
}

resource "aws_route53_record" "vpn_cert_validation" {
  provider = aws.dns

  for_each = {
    for dvo in aws_acm_certificate.vpn_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "vpn_cert" {
  certificate_arn         = aws_acm_certificate.vpn_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.vpn_cert_validation : record.fqdn]
}