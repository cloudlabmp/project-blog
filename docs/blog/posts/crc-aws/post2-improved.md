---
title: "Cloud Resume Challenge with Terraform: Deploying the Static Website"
draft: false
date:
  created: 2025-03-18
  updated: 2025-03-18
authors:
  - matthew
description: "Using Terraform to deploy a static website on AWS with S3, CloudFront, Route 53, and SSL encryption."
categories:
  - AWS
  - Terraform
  - Web Hosting
  - Cloud Resume Challenge
tags:
  - s3
  - cloudfront
  - route53
  - tls
  - terraform
  - website-hosting
---

# Cloud Resume Challenge with Terraform: Deploying the Static Website 🚀

## Introduction 🌍

In the [previous post](link-to-previous-post), we set up our Terraform environment and outlined the architecture for our Cloud Resume Challenge project. Now it's time to start building! In this post, we'll focus on deploying the first component: **the static website** that will host our resume.

## Frontend Architecture Overview 🏗️

Let's look at the specific architecture we'll implement for our frontend:

```
┌───────────┐     ┌────────────┐     ┌──────────┐     ┌────────────┐
│           │     │            │     │          │     │            │
│  Route 53 ├─────► CloudFront ├─────►    S3    │     │    ACM     │
│           │     │            │     │          │     │ Certificate│
└───────────┘     └────────────┘     └──────────┘     └────────────┘
      ▲                                    ▲                 │
      │                                    │                 │
      └────────────────────────────────────┴─────────────────┘
           DNS & Certificate Validation
```

The frontend consists of:

1. **S3 Bucket**: Hosts our HTML, CSS, and JavaScript files
2. **CloudFront**: Provides CDN capabilities for global distribution and HTTPS
3. **Route 53**: Manages our custom domain's DNS
4. **ACM**: Provides SSL/TLS certificate for HTTPS

## My HTML/CSS Resume Design Approach 🎨

Before diving into Terraform, I spent some time creating my resume in HTML and CSS. Rather than starting from scratch, I decided to use a minimalist approach with a focus on readability.

Here's a snippet of my HTML structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Matthew's Cloud Resume</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>Matthew Johnson</h1>
        <p>Cloud Engineer</p>
    </header>
    
    <section id="contact">
        <!-- Contact information -->
    </section>
    
    <section id="skills">
        <!-- Skills list -->
    </section>
    
    <section id="experience">
        <!-- Work experience -->
    </section>
    
    <section id="education">
        <!-- Education history -->
    </section>
    
    <section id="certifications">
        <!-- AWS certifications -->
    </section>
    
    <section id="projects">
        <!-- Project descriptions including this challenge -->
    </section>
    
    <section id="counter">
        <p>This page has been viewed <span id="count">0</span> times.</p>
    </section>
    
    <footer>
        <!-- Footer content -->
    </footer>
    
    <script src="counter.js"></script>
</body>
</html>
```

For CSS, I went with a responsive design that works well on both desktop and mobile devices:

```css
:root {
    --primary-color: #0066cc;
    --secondary-color: #f4f4f4;
    --text-color: #333;
    --heading-color: #222;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: var(--text-color);
    max-width: 800px;
    margin: 0 auto;
    padding: 1rem;
}

header {
    text-align: center;
    margin-bottom: 2rem;
}

h1, h2, h3 {
    color: var(--heading-color);
}

section {
    margin-bottom: 2rem;
}

/* Responsive design */
@media (max-width: 600px) {
    body {
        padding: 0.5rem;
    }
}
```

These files will be uploaded to our S3 bucket once we've provisioned it with Terraform.

## Deploying the Static Website with Terraform 🌐

Now, let's implement the Terraform code for our frontend infrastructure. We'll create modules for each component, starting with S3.

### 1. S3 Module for Website Hosting 📂

Create a file at `modules/frontend/s3.tf`:

```hcl
resource "aws_s3_bucket" "website" {
  bucket = var.website_bucket_name
  
  tags = {
    Name        = "Resume Website"
    Environment = var.environment
    Project     = "Cloud Resume Challenge"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]  # In production, restrict to your domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Add encryption for security
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Notice that I've included CORS configuration, which will be essential later when we integrate with our API. I also added encryption and versioning for better security and disaster recovery.

### 2. ACM Certificate Module 🔒

Create a file at `modules/frontend/acm.tf`:

```hcl
resource "aws_acm_certificate" "website" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "Resume Website Certificate"
    Environment = var.environment
  }
}

resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
  
  # Wait for DNS propagation
  timeouts {
    create = "30m"
  }
}
```

### 3. Route 53 for DNS Configuration 📡

Create a file at `modules/frontend/route53.tf`:

```hcl
data "aws_route53_zone" "selected" {
  name         = var.root_domain_name
  private_zone = false
}

resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.selected.zone_id
}
```

### 4. CloudFront Distribution for CDN and HTTPS 🌍

Create a file at `modules/frontend/cloudfront.tf`:

```hcl
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${var.website_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  price_class         = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.website_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Cache behaviors for specific patterns
  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.website_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.website_bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Restrict access to North America and Europe
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "FR", "ES", "IT"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.website.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Add custom error response
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  tags = {
    Name        = "Resume Website CloudFront"
    Environment = var.environment
  }

  depends_on = [aws_acm_certificate_validation.website]
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "Access identity for Resume Website CloudFront"
}

# Update S3 bucket policy to allow access from CloudFront
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}
```

I've implemented several security enhancements:

- Using origin access control for CloudFront
- Restricting the content to specific geographic regions
- Setting TLS to more modern protocols
- Creating custom error pages
- Adding better cache controls for different file types

### 5. Variables and Outputs 📝

Create files at `modules/frontend/variables.tf` and `modules/frontend/outputs.tf`:

**variables.tf**:

```hcl
variable "website_bucket_name" {
  description = "Name of the S3 bucket to store website content"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
}

variable "root_domain_name" {
  description = "Root domain name to find Route 53 hosted zone"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
```

**outputs.tf**:

```hcl
output "website_bucket_name" {
  description = "Name of the S3 bucket hosting the website"
  value       = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}

output "website_domain" {
  description = "Domain name of the website"
  value       = var.domain_name
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}
```

### 6. Main Module Configuration 🔄

Now, let's create the main configuration in `main.tf` that uses our frontend module:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "frontend" {
  source = "./modules/frontend"

  website_bucket_name = "my-resume-website-${var.environment}"
  domain_name         = var.domain_name
  root_domain_name    = var.root_domain_name
  environment         = var.environment
}
```

In `variables.tf` at the root level:

```hcl
variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
}

variable "root_domain_name" {
  description = "Root domain name to find Route 53 hosted zone"
  type        = string
}
```

### 7. Uploading Content to S3 📤

We can use Terraform to upload our website files to S3:

```hcl
# Add to modules/frontend/s3.tf
resource "aws_s3_object" "html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../../website/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../../website/index.html")
}

resource "aws_s3_object" "css" {
  bucket       = aws_s3_bucket.website.id
  key          = "styles.css"
  source       = "${path.module}/../../website/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/../../website/styles.css")
}

resource "aws_s3_object" "js" {
  bucket       = aws_s3_bucket.website.id
  key          = "counter.js"
  source       = "${path.module}/../../website/counter.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../../website/counter.js")
}

resource "aws_s3_object" "error_page" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  source       = "${path.module}/../../website/error.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../../website/error.html")
}
```

## Testing Your Deployment 🧪

After applying these Terraform configurations, you'll want to test that everything is working correctly:

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="domain_name=resume.yourdomain.com" -var="root_domain_name=yourdomain.com" -var="environment=dev"

# Apply the changes
terraform apply -var="domain_name=resume.yourdomain.com" -var="root_domain_name=yourdomain.com" -var="environment=dev"
```

Once deployment is complete, verify:

1. Your domain resolves to your CloudFront distribution
2. HTTPS is working correctly
3. Your resume appears as expected
4. The website is accessible from different locations

## Troubleshooting Common Issues ⚠️

During my implementation, I encountered several challenges:

1. **ACM Certificate Validation Delays**: It can take up to 30 minutes for certificate validation to complete. Be patient or use the AWS console to monitor progress.

2. **CloudFront Distribution Propagation**: CloudFront changes can take 15-20 minutes to propagate globally. If your site isn't loading correctly, wait and try again.

3. **S3 Bucket Policy Conflicts**: If you receive errors about conflicting bucket policies, ensure that you're not applying multiple policies to the same bucket.

4. **CORS Configuration**: Without proper CORS headers, your JavaScript won't be able to communicate with your API when we build it in the next post.

## CORS Configuration for API Integration 🔄

The Cloud Resume Challenge requires a JavaScript visitor counter that communicates with an API. To prepare for this, I've added CORS configuration to our S3 bucket. When we implement the API in the next post, we'll need to ensure it allows requests from our domain.

Here's the JavaScript snippet we'll use for the counter (to be implemented fully in the next post):

```javascript
// counter.js
document.addEventListener('DOMContentLoaded', function() {
  // We'll need to fetch from our API
  // Example: https://api.yourdomain.com/visitor-count
  
  // For now, just a placeholder
  document.getElementById('count').innerText = 'Loading...';
  
  // This will be implemented fully when we create our API
  // fetch('https://api.yourdomain.com/visitor-count')
  //   .then(response => response.json())
  //   .then(data => {
  //     document.getElementById('count').innerText = data.count;
  //   })
  //   .catch(error => console.error('Error fetching visitor count:', error));
});
```

## Lessons Learned 💡

1. **Domain Verification**: I initially struggled with ACM certificate validation. The key lesson was to ensure that the Route 53 hosted zone existed before attempting to create validation records.

2. **Terraform State Management**: When modifying existing resources, it's important to understand how Terraform tracks state. A single typo can lead to resource recreation rather than updates.

3. **Performance Optimization**: Adding specific cache behaviors for CSS and JS files significantly improved page load times. It's worth taking the time to optimize these settings.

4. **Security Considerations**: Setting up proper bucket policies and CloudFront origin access identity is critical to prevent direct access to your S3 bucket while still allowing CloudFront to serve content.

## Enhancements and Mods 🚀

Here are some ways to extend this part of the challenge:

### Developer Mod: Static Site Generator

Instead of writing plain HTML/CSS, consider using a static site generator like Hugo or Jekyll:

1. Install Hugo: `brew install hugo` (on macOS) or equivalent for your OS
2. Create a new site: `hugo new site resume-site`
3. Choose a theme or create your own
4. Generate the site: `hugo -D`
5. Modify your Terraform to upload the `public` directory contents to S3

This approach gives you templating capabilities, making it easier to update and maintain your resume.

### DevOps Mod: Content Invalidation Lambda

Create a Lambda function that automatically invalidates CloudFront cache when new content is uploaded to S3:

```hcl
resource "aws_lambda_function" "invalidation" {
  filename      = "lambda_function.zip"
  function_name = "cloudfront-invalidation"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  
  environment {
    variables = {
      DISTRIBUTION_ID = aws_cloudfront_distribution.website.id
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.website.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.invalidation.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}
```

### Security Mod: Implement DNSSEC

To prevent DNS spoofing attacks, implement DNSSEC for your domain:

```hcl
resource "aws_route53_key_signing_key" "example" {
  hosted_zone_id             = data.aws_route53_zone.selected.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = "example"
}

resource "aws_route53_hosted_zone_dnssec" "example" {
  hosted_zone_id = aws_route53_key_signing_key.example.hosted_zone_id
}

resource "aws_kms_key" "dnssec" {
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"
  policy = jsonencode({
    Statement = [
      {
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
        ],
        Effect = "Allow",
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        },
        Resource = "*"
      },
      {
        Action = "kms:*",
        Effect = "Allow",
        Principal = {
          AWS = "*"
        },
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
  })
}
```

## Next Steps ⏭️

With our static website infrastructure in place, we now have a live resume hosted on AWS with a custom domain and HTTPS. In the next post, we'll build the **backend API** using **API Gateway, Lambda, and DynamoDB** to track visitor counts.

Stay tuned to see how we implement the serverless backend and connect it to our frontend!

---

**Up Next:** [Cloud Resume Challenge with Terraform: Building the Backend API] 🔗
