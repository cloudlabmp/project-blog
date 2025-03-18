---
title: "Cloud Resume Challenge with Terraform: Automating Deployments with GitHub Actions"
date:
  created: 2025-03-20
  updated: 2025-03-20
authors:
  - matthew
description: "Setting up GitHub Actions for CI/CD automation of Terraform deployments to AWS."
categories:
  - AWS
  - Terraform
  - DevOps
  - CI/CD
  - Cloud Resume Challenge
tags:
  - github-actions
  - terraform
  - automation
  - cloud
  - devops
---

# Cloud Resume Challenge with Terraform: Automating Deployments with GitHub Actions ⚡

In our [previous posts](link-to-previous-post), we built the frontend and backend components of our cloud resume project. Now it's time to take our implementation to the next level by implementing **continuous integration and deployment (CI/CD)** with GitHub Actions.

## Why CI/CD Is Critical for Cloud Engineers 🛠️

When I first started this challenge, I manually ran `terraform apply` every time I made a change. This quickly became tedious and error-prone. As a cloud engineer, I wanted to demonstrate a professional approach to infrastructure management by implementing proper CI/CD pipelines.

Automating deployments offers several key benefits:
- **Consistency**: Every deployment follows the same process
- **Efficiency**: No more manual steps or waiting around
- **Safety**: Automated tests catch issues before they reach production
- **Auditability**: Each change is tracked with a commit and workflow run

This approach mirrors how professional cloud teams work and is a crucial skill for any cloud engineer.

## CI/CD Architecture Overview 🏗️

Here's a visual representation of our CI/CD pipelines:

```
┌─────────────┐          ┌─────────────────┐          ┌─────────────┐
│             │          │                 │          │             │
│  Developer  ├─────────►│  GitHub Actions ├─────────►│  AWS Cloud  │
│  Workstation│          │                 │          │             │
└─────────────┘          └─────────────────┘          └─────────────┘
       │                          │                          ▲
       │                          │                          │
       ▼                          ▼                          │
┌─────────────┐          ┌─────────────────┐                 │
│             │          │                 │                 │
│   GitHub    │          │  Terraform      │                 │
│ Repositories│          │  Plan & Apply   ├─────────────────┘
│             │          │                 │
└─────────────┘          └─────────────────┘
```

We'll set up separate workflows for:
1. **Frontend deployment**: Updates the S3 website content and invalidates CloudFront
2. **Backend deployment**: Runs Terraform to update our API infrastructure 
3. **Smoke tests**: Verifies that both components are working correctly after deployment

## Setting Up GitHub Repositories 📁

For this challenge, I've created two repositories:
- `cloud-resume-frontend`: Contains HTML, CSS, JavaScript, and frontend deployment workflows
- `cloud-resume-backend`: Contains Terraform configuration, Lambda code, and backend deployment workflows

### Repository Structure

Here's how I've organized my repositories:

**Frontend Repository**:
```
cloud-resume-frontend/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── website/
│   ├── index.html
│   ├── styles.css
│   ├── counter.js
│   └── error.html
├── tests/
│   └── cypress/
│       └── integration/
│           └── counter.spec.js
└── README.md
```

**Backend Repository**:
```
cloud-resume-backend/
├── .github/
│   └── workflows/
│       └── deploy.yml
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
│   ├── environments/
│   │   ├── dev/
│   │   │   └── main.tf
│   │   └── prod/
│   │       └── main.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── tests/
│   └── test_visitor_counter.py
└── README.md
```

## Securing AWS Authentication in GitHub Actions 🔒

Before setting up our workflows, we need to address a critical security concern: **how to securely authenticate GitHub Actions with AWS**. 

In the past, many tutorials recommended storing AWS access keys as GitHub Secrets. This approach works but has significant security drawbacks:
- Long-lived credentials are a security risk
- Credential rotation is manual and error-prone
- Access is typically overly permissive

Instead, I'll implement a more secure approach using **OpenID Connect (OIDC)** for keyless authentication between GitHub Actions and AWS.

### Setting Up OIDC Authentication

First, create an IAM OIDC provider for GitHub in your AWS account:

```hcl
# oidc-provider.tf
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

Then, create an IAM role that GitHub Actions can assume:

```hcl
# oidc-role.tf
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "terraform_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_permissions.arn
}

resource "aws_iam_policy" "terraform_permissions" {
  name        = "terraform-deployment-policy"
  description = "Policy for Terraform deployments via GitHub Actions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
          "cloudfront:*",
          "route53:*",
          "acm:*",
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "logs:*",
          "iam:GetRole",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

For a production environment, I would use more fine-grained permissions, but this policy works for our demonstration.

## Implementing Frontend CI/CD Workflow 🔄

Let's create a GitHub Actions workflow for our frontend repository. Create a file at `.github/workflows/deploy.yml`:

```yaml
name: Deploy Frontend

on:
  push:
    branches:
      - main
    paths:
      - 'website/**'
      - '.github/workflows/deploy.yml'
      
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: 'Deploy to S3 and Invalidate CloudFront'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Deploy to S3
        run: |
          aws s3 sync website/ s3://${{ secrets.S3_BUCKET_NAME }} --delete
      
      - name: Invalidate CloudFront Cache
        run: |
          aws cloudfront create-invalidation --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} --paths "/*"
      
  test:
    name: 'Run Smoke Tests'
    needs: deploy
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Install Cypress
        uses: cypress-io/github-action@v5
        with:
          install-command: npm install
      
      - name: Run Cypress Tests
        uses: cypress-io/github-action@v5
        with:
          command: npx cypress run
          config: baseUrl=${{ secrets.WEBSITE_URL }}
```

This workflow:
1. Authenticates using OIDC
2. Syncs website files to the S3 bucket
3. Invalidates the CloudFront cache
4. Runs Cypress tests to verify the site is working

### Creating a Cypress Test for the Frontend

Let's create a simple Cypress test to verify that our visitor counter is working. First, create a `package.json` file in the root of your frontend repository:

```json
{
  "name": "cloud-resume-frontend",
  "version": "1.0.0",
  "description": "Frontend for Cloud Resume Challenge",
  "scripts": {
    "test": "cypress open",
    "test:ci": "cypress run"
  },
  "devDependencies": {
    "cypress": "^12.0.0"
  }
}
```

Then create a Cypress test at `tests/cypress/integration/counter.spec.js`:

```javascript
describe('Resume Website Tests', () => {
  beforeEach(() => {
    // Visit the home page before each test
    cy.visit('/');
  });

  it('should load the resume page', () => {
    // Check that we have a title
    cy.get('h1').should('be.visible');
    
    // Check that key sections exist
    cy.contains('Experience').should('be.visible');
    cy.contains('Education').should('be.visible');
    cy.contains('Skills').should('be.visible');
  });

  it('should load and display the visitor counter', () => {
    // Check that the counter element exists
    cy.get('#count').should('exist');
    
    // Wait for the counter to update (should not remain at 0)
    cy.get('#count', { timeout: 10000 })
      .should('not.contain', '0')
      .should('not.contain', 'Loading');
    
    // Verify the counter shows a number
    cy.get('#count').invoke('text').then(parseFloat)
      .should('be.gt', 0);
  });
});
```

## Implementing Backend CI/CD Workflow 🔄

Now, let's create a GitHub Actions workflow for our backend repository. Create a file at `.github/workflows/deploy.yml`:

```yaml
name: Deploy Backend

on:
  push:
    branches:
      - main
    paths:
      - 'lambda/**'
      - 'terraform/**'
      - '.github/workflows/deploy.yml'
      
  pull_request:
    branches:
      - main
      
  workflow_dispatch:

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  test:
    name: 'Run Python Tests'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest boto3 moto
      
      - name: Run Tests
        run: |
          python -m pytest tests/
  
  validate:
    name: 'Validate Terraform'
    runs-on: ubuntu-latest
    needs: test
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.2.0
      
      - name: Terraform Format
        working-directory: ./terraform
        run: terraform fmt -check
      
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init -backend=false
      
      - name: Terraform Validate
        working-directory: ./terraform
        run: terraform validate
  
  plan:
    name: 'Terraform Plan'
    runs-on: ubuntu-latest
    needs: validate
    if: github.event_name == 'pull_request' || github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    environment: dev
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.2.0
      
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="key=${{ secrets.TF_STATE_KEY }}" -backend-config="region=us-east-1"
      
      - name: Terraform Plan
        working-directory: ./terraform
        run: terraform plan -var="environment=dev" -var="domain_name=${{ secrets.DOMAIN_NAME }}" -out=tfplan
      
      - name: Comment Plan on PR
        uses: actions/github-script@v6
        if: github.event_name == 'pull_request'
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `#### Terraform Format and Style 🖌\`${{ steps.fmt.outcome }}\`
            #### Terraform Plan 📖\`${{ steps.plan.outcome }}\`

            <details><summary>Show Plan</summary>

            \`\`\`terraform
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
      
      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v3
        with:
          name: tfplan
          path: ./terraform/tfplan
  
  apply:
    name: 'Terraform Apply'
    runs-on: ubuntu-latest
    needs: plan
    if: github.event_name == 'push' && github.ref == 'refs/heads/main' || github.event_name == 'workflow_dispatch'
    environment: dev
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.2.0
      
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="key=${{ secrets.TF_STATE_KEY }}" -backend-config="region=us-east-1"
      
      - name: Download Plan Artifact
        uses: actions/download-artifact@v3
        with:
          name: tfplan
          path: ./terraform
      
      - name: Terraform Apply
        working-directory: ./terraform
        run: terraform apply -auto-approve tfplan
  
  test-api:
    name: 'Test API Deployment'
    runs-on: ubuntu-latest
    needs: apply
    environment: dev
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Fetch API Endpoint
        run: |
          API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name resume-backend-dev --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)
          echo "API_ENDPOINT=$API_ENDPOINT" >> $GITHUB_ENV
      
      - name: Test API Response
        run: |
          response=$(curl -s "$API_ENDPOINT/count")
          echo "API Response: $response"
          
          # Check if the response contains a count field
          echo $response | grep -q '"count":'
          if [ $? -eq 0 ]; then
            echo "API test successful"
          else
            echo "API test failed"
            exit 1
          fi
```

This workflow is more complex and includes:
1. Running Python tests for the Lambda function
2. Validating Terraform syntax and formatting
3. Planning Terraform changes (with PR comments for review)
4. Applying Terraform changes to the environment
5. Testing the deployed API to ensure it's functioning

## Implementing Multi-Environment Deployments 🌍

One of the most valuable CI/CD patterns is deploying to multiple environments. Let's modify our backend workflow to support both development and production environments:

```yaml
# Additional job for production deployment after dev is successful
  promote-to-prod:
    name: 'Promote to Production'
    runs-on: ubuntu-latest
    needs: test-api
    environment: production
    if: github.event_name == 'workflow_dispatch'
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.2.0
      
      - name: Terraform Init
        working-directory: ./terraform/environments/prod
        run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="key=${{ secrets.TF_STATE_KEY_PROD }}" -backend-config="region=us-east-1"
      
      - name: Terraform Plan
        working-directory: ./terraform/environments/prod
        run: terraform plan -var="environment=prod" -var="domain_name=${{ secrets.DOMAIN_NAME_PROD }}" -out=tfplan
      
      - name: Terraform Apply
        working-directory: ./terraform/environments/prod
        run: terraform apply -auto-approve tfplan
      
      - name: Test Production API
        run: |
          API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name resume-backend-prod --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)
          response=$(curl -s "$API_ENDPOINT/count")
          echo "API Response: $response"
          
          # Check if the response contains a count field
          echo $response | grep -q '"count":'
          if [ $? -eq 0 ]; then
            echo "Production API test successful"
          else
            echo "Production API test failed"
            exit 1
          fi
```

### Terraform Structure for Multiple Environments

To support multiple environments, I've reorganized my Terraform configuration:

```
terraform/
├── modules/
│   ├── backend/
│   │   ├── api_gateway.tf
│   │   ├── dynamodb.tf
│   │   ├── lambda.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

Each environment directory contains its own Terraform configuration that references the shared modules.

## Implementing GitHub Security Best Practices 🔒

To enhance the security of our CI/CD pipelines, I've implemented several additional measures:

### 1. Supply Chain Security with Dependabot

Create a file at `.github/dependabot.yml` in both repositories:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # For frontend
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # For backend
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

This configuration automatically updates dependencies and identifies security vulnerabilities.

### 2. Code Scanning with CodeQL

Create a file at `.github/workflows/codeql.yml` in the backend repository:

```yaml
name: "CodeQL"

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 0'  # Run weekly

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    strategy:
      fail-fast: false
      matrix:
        language: [ 'python', 'javascript' ]

    steps:
    - name: Checkout repository
      uses: actions/checkout@v3

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: ${{ matrix.language }}

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
```

This workflow scans our code for security vulnerabilities and coding problems.

### 3. Branch Protection Rules

I've set up branch protection rules for the `main` branch in both repositories:
- Require pull request reviews before merging
- Require status checks to pass before merging
- Require signed commits
- Do not allow bypassing the above settings

## Adding Verification Tests to the Workflow 🧪

In addition to unit tests, I've added end-to-end integration tests to verify that the frontend and backend work together correctly:

### 1. Frontend-Backend Integration Test

Create a file at `tests/integration-test.js` in the frontend repository:

```javascript
const axios = require('axios');
const assert = require('assert');

// URLs to test - these should be passed as environment variables
const WEBSITE_URL = process.env.WEBSITE_URL || 'https://resume.yourdomain.com';
const API_URL = process.env.API_URL || 'https://api.yourdomain.com/count';

// Test that the API returns a valid response
async function testAPI() {
  try {
    console.log(`Testing API at ${API_URL}`);
    const response = await axios.get(API_URL);
    
    // Verify the API response contains a count
    assert(response.status === 200, `API returned status ${response.status}`);
    assert(response.data.count !== undefined, 'API response missing count field');
    assert(typeof response.data.count === 'number', 'Count is not a number');
    
    console.log(`API test successful. Count: ${response.data.count}`);
    return true;
  } catch (error) {
    console.error('API test failed:', error.message);
    return false;
  }
}

// Test that the website loads and contains necessary elements
async function testWebsite() {
  try {
    console.log(`Testing website at ${WEBSITE_URL}`);
    const response = await axios.get(WEBSITE_URL);
    
    // Verify the website loads
    assert(response.status === 200, `Website returned status ${response.status}`);
    
    // Check that the page contains some expected content
    assert(response.data.includes('<html'), 'Response is not HTML');
    assert(response.data.includes('id="count"'), 'Counter element not found');
    
    console.log('Website test successful');
    return true;
  } catch (error) {
    console.error('Website test failed:', error.message);
    return false;
  }
}

// Run all tests
async function runTests() {
  const apiResult = await testAPI();
  const websiteResult = await testWebsite();
  
  if (apiResult && websiteResult) {
    console.log('All integration tests passed!');
    process.exit(0);
  } else {
    console.error('Some integration tests failed');
    process.exit(1);
  }
}

// Run the tests
runTests();
```

Then add a step to the workflow:

```yaml
- name: Run Integration Tests
  run: |
    npm install axios
    node tests/integration-test.js
  env:
    WEBSITE_URL: ${{ secrets.WEBSITE_URL }}
    API_URL: ${{ secrets.API_URL }}
```

## Implementing Secure GitHub Action Secrets 🔐

For our GitHub Actions workflows, I've set up the following repository secrets:

- `AWS_ACCOUNT_ID`: The AWS account ID used for OIDC authentication
- `S3_BUCKET_NAME`: The name of the S3 bucket for the website
- `CLOUDFRONT_DISTRIBUTION_ID`: The ID of the CloudFront distribution
- `WEBSITE_URL`: The URL of the deployed website
- `API_URL`: The URL of the deployed API
- `TF_STATE_BUCKET`: The bucket for Terraform state
- `TF_STATE_KEY`: The key for Terraform state (dev)
- `TF_STATE_KEY_PROD`: The key for Terraform state (prod)
- `DOMAIN_NAME`: The domain name for the dev environment
- `DOMAIN_NAME_PROD`: The domain name for the prod environment

These secrets are protected by GitHub and only exposed to authorized workflow runs.

## Managing Manual Approvals for Production Deployments 🚦

For production deployments, I've added a manual approval step using GitHub Environments:

1. Go to your repository settings
2. Navigate to Environments
3. Create a new environment called "production"
4. Enable "Required reviewers" and add yourself
5. Configure "Deployment branches" to limit deployments to specific branches

Now, production deployments will require explicit approval from an authorized reviewer.

## Monitoring Deployment Status and Notifications 📊

To stay informed about deployment status, I've added notifications to the workflow:

```yaml
- name: Notify Deployment Success
  if: success()
  uses: rtCamp/action-slack-notify@v2
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
    SLACK_TITLE: Deployment Successful
    SLACK_MESSAGE: "✅ Deployment to ${{ github.workflow }} was successful!"
    SLACK_COLOR: good

- name: Notify Deployment Failure
  if: failure()
  uses: rtCamp/action-slack-notify@v2
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
    SLACK_TITLE: Deployment Failed
    SLACK_MESSAGE: "❌ Deployment to ${{ github.workflow }} failed!"
    SLACK_COLOR: danger
```

This sends notifications to a Slack channel when deployments succeed or fail.

## Implementing Additional Security for AWS CloudFront 🔒

To enhance the security of our CloudFront distribution, I've added a custom response headers policy:

```hcl
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "security-headers-policy"

  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none';"
      override = true
    }
    
    content_type_options {
      override = true
    }
    
    frame_options {
      frame_option = "DENY"
      override = true
    }
    
    referrer_policy {
      referrer_policy = "same-origin"
      override = true
    }
    
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains = true
      preload = true
      override = true
    }
    
    xss_protection {
      mode_block = true
      protection = true
      override = true
    }
  }
}
```

Then reference this policy in the CloudFront distribution:

```hcl
resource "aws_cloudfront_distribution" "website" {
  # ... other configuration ...
  
  default_cache_behavior {
    # ... other configuration ...
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }
}
```

## Lessons Learned 💡

Implementing CI/CD for this project taught me several valuable lessons:

1. **Start Simple, Then Iterate**: My first workflow was basic - just syncing files to S3. As I gained confidence, I added testing, multiple environments, and security features.

2. **Security Is Non-Negotiable**: Using OIDC for authentication instead of long-lived credentials was a game-changer for security. This approach follows AWS best practices and eliminates credential management headaches.

3. **Test Everything**: Automated tests at every level (unit, integration, end-to-end) catch issues early. The time invested in writing tests paid off with more reliable deployments.

4. **Environment Separation**: Keeping development and production environments separate allowed me to test changes safely before affecting the live site.

5. **Infrastructure as Code Works**: Using Terraform to define all infrastructure components made the CI/CD process much more reliable. Everything is tracked, versioned, and repeatable.

## My Integration Challenges and Solutions 🧩

During implementation, I encountered several challenges:

1. **CORS Issues**: The API and website needed proper CORS configuration to work together. Adding the correct headers in both Lambda and API Gateway fixed this.

2. **Environment Variables**: Managing different configurations for dev and prod was tricky. I solved this by using GitHub environment variables and separate Terraform workspaces.

3. **Cache Invalidation Delays**: Changes to the website sometimes weren't visible immediately due to CloudFront caching. Adding proper cache invalidation to the workflow fixed this.

4. **State Locking**: When multiple workflow runs executed simultaneously, they occasionally conflicted on Terraform state. Using DynamoDB for state locking resolved this issue.

## DevOps Mod: Multi-Stage Pipeline with Pull Request Environments 🚀

To extend this challenge further, I implemented a feature that creates temporary preview environments for pull requests:

```yaml
  create_preview:
    name: 'Create Preview Environment'
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.2.0
      
      - name: Generate Unique Environment Name
        run: |
          PR_NUMBER=${{ github.event.pull_request.number }}
          BRANCH_NAME=$(echo ${{ github.head_ref }} | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
          ENV_NAME="pr-${PR_NUMBER}-${BRANCH_NAME}"
          echo "ENV_NAME=${ENV_NAME}" >> $GITHUB_ENV
      
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="key=preview/${{ env.ENV_NAME }}/terraform.tfstate" -backend-config="region=us-east-1"
      
      - name: Terraform Apply
        working-directory: ./terraform
        run: |
          terraform apply -auto-approve \
            -var="environment=${{ env.ENV_NAME }}" \
            -var="domain_name=pr-${{ github.event.pull_request.number }}.${{ secrets.DOMAIN_NAME }}"
      
      - name: Comment Preview URL
        uses: actions/github-script@v6
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `## 🚀 Preview Environment Deployed
            
            Preview URL: https://pr-${{ github.event.pull_request.number }}.${{ secrets.DOMAIN_NAME }}
            
            API Endpoint: https://api-pr-${{ github.event.pull_request.number }}.${{ secrets.DOMAIN_NAME }}/count
            
            This environment will be automatically deleted when the PR is closed.`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
```

And add a cleanup job to delete the preview environment when the PR is closed:

```yaml
  cleanup_preview:
    name: 'Cleanup Preview Environment'
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    
    steps:
      # Similar to create_preview but with terraform destroy
```

## Security Mod: Implementing AWS Secrets Manager for API Keys 🔐

To enhance the security of our API, I added API key authentication using AWS Secrets Manager:

```hcl
# Create a secret to store the API key
resource "aws_secretsmanager_secret" "api_key" {
  name        = "resume-api-key-${var.environment}"
  description = "API key for the Resume API"
}

# Generate a random API key
resource "random_password" "api_key" {
  length  = 32
  special = false
}

# Store the API key in Secrets Manager
resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = random_password.api_key.result
}

# Add API key to API Gateway
resource "aws_api_gateway_api_key" "visitor_counter" {
  name = "visitor-counter-key-${var.environment}"
}

resource "aws_api_gateway_usage_plan" "visitor_counter" {
  name = "visitor-counter-usage-plan-${var.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.visitor_counter.id
    stage  = aws_api_gateway_deployment.visitor_counter.stage_name
  }

  quota_settings {
    limit  = 1000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 10
    rate_limit  = 5
  }
}

resource "aws_api_gateway_usage_plan_key" "visitor_counter" {
  key_id        = aws_api_gateway_api_key.visitor_counter.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.visitor_counter.id
}

# Update the Lambda function to verify the API key
resource "aws_lambda_function" "visitor_counter" {
  # ... existing configuration ...
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_counter.name
      ALLOWED_ORIGIN = var.website_domain
      API_KEY_SECRET = aws_secretsmanager_secret.api_key.name
    }
  }
}
```

Then, modify the Lambda function to retrieve and validate the API key:

```python
import boto3
import json
import os

# Initialize Secrets Manager client
secretsmanager = boto3.client('secretsmanager')

def get_api_key():
    """Retrieve the API key from Secrets Manager"""
    secret_name = os.environ['API_KEY_SECRET']
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    return response['SecretString']

def lambda_handler(event, context):
    # Verify API key
    api_key = event.get('headers', {}).get('x-api-key')
    expected_api_key = get_api_key()
    
    if api_key != expected_api_key:
        return {
            'statusCode': 403,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Forbidden',
                'message': 'Invalid API key'
            })
        }
    
    # Rest of the function...
```

## Next Steps ⏭️

With our CI/CD pipelines in place, our Cloud Resume Challenge implementation is complete! In the final post, we'll reflect on the project as a whole, discuss lessons learned, and explore potential future enhancements.

---

**Up Next:** [Cloud Resume Challenge with Terraform: Final Thoughts & Lessons Learned] 🔗
