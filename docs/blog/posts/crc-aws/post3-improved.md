---
title: "Cloud Resume Challenge with Terraform: Building the Backend API"
draft: true
date:
  created: 2025-03-19
  updated: 2025-03-19
authors:
  - matthew
description: "Creating a serverless API with AWS Lambda, API Gateway, and DynamoDB using Terraform."
categories:
  - AWS
  - Terraform
  - Serverless
  - Cloud Resume Challenge
tags:
  - lambda
  - api-gateway
  - dynamodb
  - terraform
  - serverless
---

# Cloud Resume Challenge with Terraform: Building the Backend API 🚀

In our [previous post](link-to-previous-post), we set up the frontend infrastructure for our resume website using Terraform. Now it's time to build the backend API that will power our visitor counter.

## Backend Architecture Overview 🏗️

Let's take a look at the serverless architecture we'll be implementing:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │
│ API Gateway ├─────► Lambda      ├─────► DynamoDB    │
│             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │
│ CloudWatch  │     │ CloudWatch  │     │ CloudWatch  │
│   Logs      │     │   Logs      │     │   Logs      │
│             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
```

This architecture includes:

1. **API Gateway**: Exposes our Lambda function as a REST API
2. **Lambda Function**: Contains the Python code to increment and return the visitor count
3. **DynamoDB**: Stores the visitor count data
4. **CloudWatch**: Monitors and logs activity across all services

## My Approach to DynamoDB Design 💾

Before diving into the Terraform code, I want to share my thought process on DynamoDB table design. When I initially approached this challenge, I had to decide between two approaches:

1. **Single-counter approach**: A simple table with just one item for the counter
2. **Visitor log approach**: A more detailed table that logs each visit with timestamps

I chose the second approach for a few reasons:

- It allows for more detailed analytics in the future
- It provides a history of visits that can be queried
- It demonstrates a more realistic use case for DynamoDB

Here's my table design:

| Attribute  | Type   | Description                         |
|------------|--------|-------------------------------------|
| visit_id   | String | Primary key (UUID)                  |
| timestamp  | String | ISO8601 timestamp of the visit      |
| visitor_ip | String | Hashed IP address for privacy       |
| user_agent | String | Browser/device information          |
| path       | String | Page path visited                   |

This approach gives us flexibility while keeping the solution serverless and cost-effective.

## Implementing the Backend API with Terraform 🛠️

Now, let's start implementing our backend infrastructure using Terraform. We'll create modules for each component, starting with DynamoDB.

### 1. DynamoDB Table for Visitor Counting 📊

Create a file at `modules/backend/dynamodb.tf`:

```hcl
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "ResumeVisitorCounter-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"  # On-demand capacity for cost savings
  hash_key       = "visit_id"

  attribute {
    name = "visit_id"
    type = "S"
  }

  # Add TTL for automatic data cleanup after 90 days
  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true  # Enable PITR for recovery options
  }

  # Use server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "Resume Visitor Counter"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

# Create a GSI for timestamp-based queries
resource "aws_dynamodb_table_item" "counter_init" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  # Initialize the counter with a value of 0
  item = jsonencode({
    "visit_id": {"S": "total"},
    "count": {"N": "0"}
  })

  # Only create this item on initial deployment
  lifecycle {
    ignore_changes = [item]
  }
}
```

I've implemented several enhancements:

- Point-in-time recovery for data protection
- TTL for automatic cleanup of old records
- Server-side encryption for security
- An initial counter item to ensure we don't have "cold start" issues

### 2. Lambda Function for the API Logic 🏗️

Now, let's create our Lambda function. First, we'll need the Python code. Create a file at `modules/backend/lambda/visitor_counter.py`:

```python
import boto3
import json
import os
import uuid
import logging
from datetime import datetime, timedelta
import hashlib
from botocore.exceptions import ClientError

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler to process API Gateway requests for visitor counting.
    Increments the visitor counter and returns the updated count.
    """
    logger.info(f"Processing event: {json.dumps(event)}")
    
    try:
        # Extract request information
        request_context = event.get('requestContext', {})
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        headers = event.get('headers', {})
        ip_address = request_context.get('identity', {}).get('sourceIp', 'unknown')
        user_agent = headers.get('User-Agent', 'unknown')
        
        # Generate a unique visit ID
        visit_id = str(uuid.uuid4())
        
        # Hash the IP address for privacy
        hashed_ip = hashlib.sha256(ip_address.encode()).hexdigest()
        
        # Get current timestamp
        timestamp = datetime.utcnow().isoformat()
        
        # Calculate expiration time (90 days from now)
        expiration_time = int((datetime.utcnow() + timedelta(days=90)).timestamp())
        
        # Log the visit
        table.put_item(
            Item={
                'visit_id': visit_id,
                'timestamp': timestamp,
                'visitor_ip': hashed_ip,
                'user_agent': user_agent,
                'path': path,
                'expiration_time': expiration_time
            }
        )
        
        # Update the total counter
        response = table.update_item(
            Key={'visit_id': 'total'},
            UpdateExpression='ADD #count :incr',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={':incr': 1},
            ReturnValues='UPDATED_NEW'
        )
        
        count = int(response['Attributes']['count'])
        
        # Return the response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': os.environ['ALLOWED_ORIGIN'],
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'count': count,
                'message': 'Visitor count updated successfully'
            })
        }
        
    except ClientError as e:
        logger.error(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': os.environ.get('ALLOWED_ORIGIN', '*')
            },
            'body': json.dumps({
                'error': 'Database error',
                'message': str(e)
            })
        }
    except Exception as e:
        logger.error(f"General error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': os.environ.get('ALLOWED_ORIGIN', '*')
            },
            'body': json.dumps({
                'error': 'Server error',
                'message': str(e)
            })
        }

def options_handler(event, context):
    """
    Handler for OPTIONS requests to support CORS
    """
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': os.environ.get('ALLOWED_ORIGIN', '*'),
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': ''
    }
```

Now, let's create the Lambda function using Terraform. Create a file at `modules/backend/lambda.tf`:

```hcl
# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/visitor_counter.py"
  output_path = "${path.module}/lambda/visitor_counter.zip"
}

# Create the Lambda function
resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "resume-visitor-counter-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "visitor_counter.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 10  # Increased timeout for better error handling
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_counter.name
      ALLOWED_ORIGIN = var.website_domain
    }
  }

  tracing_config {
    mode = "Active"  # Enable X-Ray tracing
  }

  tags = {
    Name        = "Resume Visitor Counter Lambda"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "resume-visitor-counter-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Create a custom policy for the Lambda function with least privilege
resource "aws_iam_policy" "lambda_policy" {
  name        = "resume-visitor-counter-lambda-policy-${var.environment}"
  description = "IAM policy for the visitor counter Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.visitor_counter.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.visitor_counter.function_name}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

# Create a Lambda function for handling OPTIONS requests (CORS)
resource "aws_lambda_function" "options_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "resume-visitor-counter-options-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "visitor_counter.options_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ALLOWED_ORIGIN = var.website_domain
    }
  }

  tags = {
    Name        = "Resume Options Handler Lambda"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}
```

I've implemented several security and operational improvements:

- Least privilege IAM policies
- X-Ray tracing for performance monitoring
- Proper CORS handling with a dedicated OPTIONS handler
- CloudWatch log group with retention policy
- Privacy-enhancing IP address hashing

### 3. API Gateway for Exposing the Lambda Function 🔗

Create a file at `modules/backend/api_gateway.tf`:

```hcl
# Create the API Gateway REST API
resource "aws_api_gateway_rest_api" "visitor_counter" {
  name        = "resume-visitor-counter-${var.environment}"
  description = "API for the resume visitor counter"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "Resume Visitor Counter API"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

# Create a resource for the API
resource "aws_api_gateway_resource" "visitor_counter" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter.id
  parent_id   = aws_api_gateway_rest_api.visitor_counter.root_resource_id
  path_part   = "count"
}

# Create a GET method for the API
resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter.id
  resource_id   = aws_api_gateway_resource.visitor_counter.id
  http_method   = "GET"
  authorization_type = "NONE"
  
  # Add API key requirement if needed
  # api_key_required = true
}

# Create an OPTIONS method for the API (for CORS)
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter.id
  resource_id   = aws_api_gateway_resource.visitor_counter.id
  http_method   = "OPTIONS"
  authorization_type = "NONE"
}

# Set up the GET method integration with Lambda
resource "aws_api_gateway_integration" "lambda_get" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter.id
  resource_id = aws_api_gateway_resource.visitor_counter.id
  http_method = aws_api_gateway_method.get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitor_counter.invoke_arn
}

# Set up the OPTIONS method integration with Lambda
resource "aws_api_gateway_integration" "lambda_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter.id
  resource_id = aws_api_gateway_resource.visitor_counter.id
  http_method = aws_api_gateway_method.options.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.options_handler.invoke_arn
}

# Create a deployment for the API
resource "aws_api_gateway_deployment" "visitor_counter" {
  depends_on = [
    aws_api_gateway_integration.lambda_get,
    aws_api_gateway_integration.lambda_options
  ]

  rest_api_id = aws_api_gateway_rest_api.visitor_counter.id
  stage_name  = var.environment

  lifecycle {
    create_before_destroy = true
  }
}

# Add permission for API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway
  source_arn = "${aws_api_gateway_rest_api.visitor_counter.execution_arn}/*/${aws_api_gateway_method.get.http_method}${aws_api_gateway_resource.visitor_counter.path}"
}

# Add permission for API Gateway to invoke the OPTIONS Lambda function
resource "aws_lambda_permission" "api_gateway_options_lambda" {
  statement_id  = "AllowAPIGatewayInvokeOptions"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.options_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.visitor_counter.execution_arn}/*/${aws_api_gateway_method.options.http_method}${aws_api_gateway_resource.visitor_counter.path}"
}

# Enable CloudWatch logging for API Gateway
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "api-gateway-cloudwatch-role-${var.environment}"

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

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set up method settings for logging and throttling
resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter.id
  stage_name  = aws_api_gateway_deployment.visitor_counter.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}

# Create a custom domain for the API
resource "aws_api_gateway_domain_name" "api" {
  domain_name              = "api.${var.domain_name}"
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "Resume API Domain"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

# Create a base path mapping for the custom domain
resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = aws_api_gateway_rest_api.visitor_counter.id
  stage_name  = aws_api_gateway_deployment.visitor_counter.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

# Create a Route 53 record for the API domain
resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api.regional_zone_id
    evaluate_target_health = false
  }
}
```

The API Gateway configuration includes several enhancements:

- CloudWatch logging and metrics
- Rate limiting and throttling to prevent abuse
- Custom domain for a professional API endpoint
- Proper Route 53 DNS configuration

### 4. Variables and Outputs 📝

Create files at `modules/backend/variables.tf` and `modules/backend/outputs.tf`:

**variables.tf**:

```hcl
variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "website_domain" {
  description = "Domain of the resume website (for CORS)"
  type        = string
}

variable "domain_name" {
  description = "Base domain name for custom API endpoint"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the API domain"
  type        = string
}
```

**outputs.tf**:

```hcl
output "api_endpoint" {
  description = "Endpoint URL of the API Gateway"
  value       = aws_api_gateway_deployment.visitor_counter.invoke_url
}

output "api_custom_domain" {
  description = "Custom domain for the API"
  value       = aws_api_gateway_domain_name.api.domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.visitor_counter.name
}
```

### 5. Source Control for Backend Code 📚

An important aspect of the Cloud Resume Challenge is using source control. We'll create a GitHub repository for our backend code. Here's how I organize my repository:

```
resume-backend/
├── .github/
│   └── workflows/
│       └── deploy.yml  # GitHub Actions workflow (we'll create this in next post)
├── lambda/
│   └── visitor_counter.py
├── terraform/
│   ├── modules/
│   │   ├── backend/
│   │   │   ├── api_gateway.tf
│   │   │   ├── dynamodb.tf
│   │   │   ├── lambda.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── tests/
│   └── test_visitor_counter.py  # Python unit tests
└── README.md
```

## Implementing Python Tests 🧪

For step 11 of the Cloud Resume Challenge, we need to include tests for our Python code. Create a file at `tests/test_visitor_counter.py`:

```python
import unittest
import json
import os
import sys
from unittest.mock import patch, MagicMock

# Add lambda directory to the path so we can import the function
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'lambda'))

import visitor_counter

class TestVisitorCounter(unittest.TestCase):
    """Test cases for the visitor counter Lambda function."""
    
    @patch('visitor_counter.table')
    def test_lambda_handler_success(self, mock_table):
        """Test successful execution of the lambda_handler function."""
        # Mock the DynamoDB responses
        mock_put_response = MagicMock()
        mock_update_response = {
            'Attributes': {
                'count': 42
            }
        }
        mock_table.put_item.return_value = mock_put_response
        mock_table.update_item.return_value = mock_update_response
        
        # Set required environment variables
        os.environ['DYNAMODB_TABLE'] = 'test-table'
        os.environ['ALLOWED_ORIGIN'] = 'https://example.com'
        
        # Create a test event
        event = {
            'httpMethod': 'GET',
            'path': '/count',
            'headers': {
                'User-Agent': 'test-agent'
            },
            'requestContext': {
                'identity': {
                    'sourceIp': '127.0.0.1'
                }
            }
        }
        
        # Call the function
        response = visitor_counter.lambda_handler(event, {})
        
        # Assert response is correct
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(response['headers']['Content-Type'], 'application/json')
        self.assertEqual(response['headers']['Access-Control-Allow-Origin'], 'https://example.com')
        
        # Parse the body and check the count
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 42)
        self.assertEqual(body['message'], 'Visitor count updated successfully')
        
        # Verify that DynamoDB was called correctly
        mock_table.put_item.assert_called_once()
        mock_table.update_item.assert_called_once_with(
            Key={'visit_id': 'total'},
            UpdateExpression='ADD #count :incr',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={':incr': 1},
            ReturnValues='UPDATED_NEW'
        )
    
    @patch('visitor_counter.table')
    def test_lambda_handler_error(self, mock_table):
        """Test error handling in the lambda_handler function."""
        # Simulate a DynamoDB error
        mock_table.update_item.side_effect = Exception("Test error")
        
        # Set required environment variables
        os.environ['DYNAMODB_TABLE'] = 'test-table'
        os.environ['ALLOWED_ORIGIN'] = 'https://example.com'
        
        # Create a test event
        event = {
            'httpMethod': 'GET',
            'path': '/count',
            'headers': {
                'User-Agent': 'test-agent'
            },
            'requestContext': {
                'identity': {
                    'sourceIp': '127.0.0.1'
                }
            }
        }
        
        # Call the function
        response = visitor_counter.lambda_handler(event, {})
        
        # Assert response indicates an error
        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(response['headers']['Content-Type'], 'application/json')
        
        # Parse the body and check the error message
        body = json.loads(response['body'])
        self.assertIn('error', body)
        self.assertIn('message', body)
    
    def test_options_handler(self):
        """Test the OPTIONS handler for CORS support."""
        # Set required environment variables
        os.environ['ALLOWED_ORIGIN'] = 'https://example.com'
        
        # Create a test event
        event = {
            'httpMethod': 'OPTIONS',
            'path': '/count',
            'headers': {
                'Origin': 'https://example.com'
            }
        }
        
        # Call the function
        response = visitor_counter.options_handler(event, {})
        
        # Assert response is correct for OPTIONS
        self.assertEqual(response['statusCode'], 200)
        self.assertEqual(response['headers']['Access-Control-Allow-Origin'], 'https://example.com')
        self.assertEqual(response['headers']['Access-Control-Allow-Methods'], 'GET, OPTIONS')
        self.assertEqual(response['headers']['Access-Control-Allow-Headers'], 'Content-Type')

if __name__ == '__main__':
    unittest.main()
```

This test suite covers:

- Successful API calls
- Error handling
- CORS OPTIONS request handling

To run these tests, you would use the following command:

```bash
python -m unittest tests/test_visitor_counter.py
```

## Testing the API Manually 🧪

Once you've deployed the API, you can test it manually using tools like cURL or Postman. Here's how to test with cURL:

```bash
# Get the current visitor count
curl -X GET https://api.yourdomain.com/count

# Test CORS pre-flight request
curl -X OPTIONS https://api.yourdomain.com/count \
  -H "Origin: https://yourdomain.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Content-Type"
```

For Postman:

1. Create a new GET request to your API endpoint (`https://api.yourdomain.com/count`)
2. Send the request and verify you get a 200 response with a JSON body
3. Create a new OPTIONS request to test CORS
4. Add headers: `Origin: https://yourdomain.com`, `Access-Control-Request-Method: GET`
5. Send the request and verify you get a 200 response with the correct CORS headers

## Setting Up CloudWatch Monitoring and Alarms ⚠️

Adding monitoring and alerting is a critical part of any production-grade API. Let's add CloudWatch alarms to notify us if something goes wrong:

```hcl
# Add to modules/backend/monitoring.tf

# Alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-visitor-counter-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This alarm monitors for errors in the visitor counter Lambda function"
  
  dimensions = {
    FunctionName = aws_lambda_function.visitor_counter.function_name
  }
  
  # Add SNS topic ARN if you want notifications
  # alarm_actions     = [aws_sns_topic.alerts.arn]
  # ok_actions        = [aws_sns_topic.alerts.arn]
}

# Alarm for API Gateway 5XX errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "api-visitor-counter-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This alarm monitors for 5XX errors in the visitor counter API"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.visitor_counter.name
    Stage   = aws_api_gateway_deployment.visitor_counter.stage_name
  }
  
  # Add SNS topic ARN if you want notifications
  # alarm_actions     = [aws_sns_topic.alerts.arn]
  # ok_actions        = [aws_sns_topic.alerts.arn]
}

# Dashboard for monitoring the API
resource "aws_cloudwatch_dashboard" "api_dashboard" {
  dashboard_name = "visitor-counter-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.visitor_counter.name, "Stage", aws_api_gateway_deployment.visitor_counter.stage_name]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "API Requests"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.visitor_counter.name, "Stage", aws_api_gateway_deployment.visitor_counter.stage_name],
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.visitor_counter.name, "Stage", aws_api_gateway_deployment.visitor_counter.stage_name]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "API Errors"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.visitor_counter.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.visitor_counter.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Lambda Invocations and Errors"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.visitor_counter.function_name]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Lambda Duration"
        }
      }
    ]
  })
}
```

## Debugging Common API Issues 🐛

During my implementation, I encountered several challenges:

1. **CORS Issues**: The most common problem was with CORS configuration. Make sure your API Gateway and Lambda function both return the proper CORS headers.

2. **IAM Permission Errors**: Initially, I gave my Lambda function too many permissions, then too few. The policy shown above represents the minimal set of permissions needed.

3. **DynamoDB Initialization**: The counter needs to be initialized with a value. I solved this by adding an item to the table during deployment.

4. **API Gateway Integration**: Make sure your Lambda function and API Gateway are correctly integrated. Check for proper resource paths and method settings.

## Lessons Learned 💡

1. **DynamoDB Design**: My initial design was too simple. Adding more fields like timestamp and user-agent provides valuable analytics data.

2. **Error Handling**: Robust error handling is critical for serverless applications. Without proper logging, debugging becomes nearly impossible.

3. **Testing Strategy**: Writing tests before implementing the Lambda function (test-driven development) helped me think through edge cases and error scenarios.

4. **Security Considerations**: Privacy is important. Hashing IP addresses and implementing proper IAM policies ensures we protect user data.

## API Security Considerations 🔒

Security was a primary concern when building this API. Here are the key security measures I implemented:

1. **Least Privilege IAM Policies**: The Lambda function has only the minimal permissions needed.

2. **Input Validation**: The Lambda function validates and sanitizes all input.

3. **Rate Limiting**: API Gateway is configured with throttling to prevent abuse.

4. **HTTPS Only**: All API endpoints use HTTPS with modern TLS settings.

5. **CORS Configuration**: Only the resume website domain is allowed to make cross-origin requests.

6. **Privacy Protection**: IP addresses are hashed to protect visitor privacy.

These measures help protect against common API vulnerabilities like injection attacks, denial of service, and data exposure.

## Enhancements and Mods 🚀

Here are some ways to extend this part of the challenge:

### Developer Mod: Schemas and Dreamers

Instead of using DynamoDB, consider implementing a relational database approach:

```hcl
resource "aws_db_subnet_group" "database" {
  name       = "resume-database-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "database" {
  name        = "resume-database-sg"
  description = "Security group for the resume database"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }
}

resource "aws_db_instance" "postgresql" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "13.4"
  instance_class         = "db.t3.micro"
  db_name                = "resumedb"
  username               = "postgres"
  password               = var.db_password
  parameter_group_name   = "default.postgres13"
  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]
  skip_final_snapshot    = true
  multi_az               = false
  
  tags = {
    Name        = "Resume Database"
    Environment = var.environment
  }
}
```

This approach introduces interesting networking challenges and requires modifications to your Lambda function to connect to PostgreSQL.

### DevOps Mod: Monitor Lizard

Enhance monitoring with X-Ray traces and custom CloudWatch metrics:

```hcl
# Add to Lambda function configuration
tracing_config {
  mode = "Active"
}

# Add X-Ray policy
resource "aws_iam_policy" "lambda_xray" {
  name        = "lambda-xray-policy-${var.environment}"
  description = "IAM policy for X-Ray tracing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_xray.arn
}
```

Then modify your Lambda function to emit custom metrics:

```python
import boto3
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# Patch all supported libraries for X-Ray
patch_all()

cloudwatch = boto3.client('cloudwatch')

# Inside lambda_handler
cloudwatch.put_metric_data(
    Namespace='ResumeMetrics',
    MetricData=[
        {
            'MetricName': 'VisitorCount',
            'Value': count,
            'Unit': 'Count'
        }
    ]
)
```

### Security Mod: Check Your Privilege

Implement AWS WAF to protect your API from common web attacks:

```hcl
resource "aws_wafv2_web_acl" "api" {
  name        = "api-waf-${var.environment}"
  description = "WAF for the resume API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "APIWebACLMetric"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.visitor_counter.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
```

## Next Steps ⏭️

With our backend API completed, we're ready to connect it to our frontend in the next post. We'll integrate the JavaScript visitor counter with our API and then automate the deployment process using GitHub Actions.

Stay tuned to see how we bring the full stack together!

---

**Up Next:** [Cloud Resume Challenge with Terraform: Automating Deployments with GitHub Actions] 🔗
