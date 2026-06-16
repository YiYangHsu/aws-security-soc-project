provider "aws" {
  region = "us-east-1"
}

##Lambda Resource

resource "aws_iam_role" "lambda_role" {
  name = "soc_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "soc_lambda" {
  function_name = "soc-demo-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  filename         = "${path.module}/lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/function.zip")

  depends_on = [
    aws_cloudwatch_log_group.soc_log_group
  ]

  tags = {
    Environment = "Lab"
    Project     = "AWS-SOC"
    Owner       = "Yang"
  }
}

##API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "soc-demo-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.http_api.id

  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.soc_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /security"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/soc-demo-api"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soc_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "soc_log_group" {
  name              = "/aws/lambda/soc-demo-lambda"
  skip_destroy      = false
  retention_in_days = 7
  # Security investigations often happen AFTER incidents
}

resource "aws_cloudwatch_log_metric_filter" "api_requests_filter" {
  name           = "ApiRequestCount"
  log_group_name = aws_cloudwatch_log_group.soc_log_group.name

  pattern = "API_REQUEST"

  metric_transformation {
    name      = "ApiRequestMetric"
    namespace = "SOCProject"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_api_requests" {
  alarm_name          = "HighAPIRequestAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApiRequestMetric"
  namespace           = "SOCProject"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  alarm_description = "Triggered when API requests exceed threshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]
}

resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
  #kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "yiyanghsu@gmail.com"
}

resource "aws_iam_role" "incident_respones_role" {
  name = "incident_response_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "incident_resoibse_basic_execution" {
  role       = aws_iam_role.incident_respones_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "incident_response_lambda" {
  function_name = "incident-response-lambda"

  role    = aws_iam_role.incident_respones_role.arn
  handler = "index.handler"
  runtime = "nodejs18.x"

  filename         = "${path.module}/incident-response/function.zip"
  source_code_hash = filebase64sha256("${path.module}/incident-response/function.zip")

  tags = {
    Environment = "Lab"
    Project     = "AWS-SOC"
    Owner       = "Yang"
  }
}

resource "aws_cloudwatch_log_group" "response_log_group" {
  name              = "/aws/lambda/incident-response-lambda"
  skip_destroy      = false
  retention_in_days = 7
  # Security investigations often happen AFTER incidents
}

resource "aws_sns_topic_subscription" "incident_response_subscription" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.incident_response_lambda.arn
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_response_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.security_alerts.arn
}

resource "aws_cloudwatch_log_metric_filter" "suspicious_user_agent_filter" {
  name           = "SuspiciousUserAgentFilter"
  log_group_name = aws_cloudwatch_log_group.soc_log_group.name

  pattern = "SUSPICIOUS_USER_AGENT"

  metric_transformation {
    name      = "SuspiciousUserAgentMetric"
    namespace = "SOCProject"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "suspicious_user_agent_alarm" {
  alarm_name          = "SuspiciousUserAgentAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "SuspiciousUserAgentMetric"
  namespace   = "SOCProject"

  period    = 60
  statistic = "Sum"
  threshold = 2

  alarm_description  = "Detect suspicious user-agent activity"
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.security_alerts.arn]

}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "LambdaErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "Errors"
  namespace   = "AWS/Lambda"

  period    = 60
  statistic = "Sum"
  threshold = 1

  dimensions = {
    FunctionName = aws_lambda_function.soc_lambda.function_name
  }

  alarm_description = "Detect Lambda execution errors"

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]

}

resource "aws_cloudwatch_dashboard" "soc_dashboard" {
  dashboard_name = "AWS-SOC-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "API Requests"

          metrics = [
            ["SOCProject", "ApiRequestMetric"]
          ]

          view   = "timeSeries"
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "Suspicious User Agents"

          metrics = [
            ["SOCProject", "SuspiciousUserAgentMetric"]
          ]

          view   = "timeSeries"
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title = "Lambda Errors"

          metrics = [
            [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              "soc-demo-lambda"
            ]
          ]

          view   = "timeSeries"
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title = "Lambda Invocations"

          metrics = [
            [
              "AWS/Lambda",
              "Invocations",
              "FunctionName",
              "soc-demo-lambda"
            ]
          ]

          view   = "timeSeries"
          region = "us-east-1"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          title = "Security Alarms"

          alarms = [
            aws_cloudwatch_metric_alarm.high_api_requests.arn,
            aws_cloudwatch_metric_alarm.suspicious_user_agent_alarm.arn,
            aws_cloudwatch_metric_alarm.lambda_error_alarm.arn
          ]
        }
      }
    ]
  })
}

resource "time_static" "bucket_timestamp" {

}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "yang-aws-soc-cloudtrail-logs-20260611"
}

# Add bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Add bucket ACL (required for CloudTrail)
resource "aws_s3_bucket_acl" "cloudtrail_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudtrail_logs]
  bucket     = aws_s3_bucket.cloudtrail_logs.id
  acl        = "private"
}

# Add the bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "soc_trail" {
  name                          = "soc-security-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true

  enable_logging             = true
  enable_log_file_validation = true


  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role.arn
}

# Add IAM role for CloudTrail to send logs to CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  name = "cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/soc-security-trail"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_metric_filter" "iam_user_created" {
  name           = "IAMUserCreated"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  pattern = "{ ($.eventName = CreateUser) }"

  metric_transformation {
    name      = "IAMUserCreatedMetric"
    namespace = "SOCProject"
    value     = "1"
  }
}


resource "aws_cloudwatch_log_metric_filter" "root_usage_filter" {
  name           = "RootAccountUsage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  pattern = "{$.userIdentity.type = Root}"

  metric_transformation {
    name      = "RootUsageMetric"
    namespace = "SOCProject"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_user_created_alarm" {
  alarm_name          = "IAMUserCreatedAlarm"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1

  metric_name = "IAMUserCreatedMetric"
  namespace   = "SOCProject"

  statistic = "Sum"
  period    = 300

  threshold = 0

  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "root_usage_alarm" {
  alarm_name = "RootAccountUsageAlarm"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  metric_name = "RootUsageMetric"
  namespace   = "SOCProject"

  statistic = "Sum"
  period    = 300

  threshold = 0

  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]
}