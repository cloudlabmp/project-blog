---
title: "Cloud Resume Challenge with Terraform: Introduction & Setup"
draft: true
date:
  created: 2025-03-17
  updated: 2025-03-17
authors:
  - matthew
description: "An introduction to the Cloud Resume Challenge and how to set up Terraform for AWS infrastructure as code."
categories:
  - AWS
  - Terraform
  - DevOps
  - Cloud Resume Challenge
tags:
  - cloud
  - terraform
  - aws
  - infrastructure-as-code
  - resume-challenge
---

# Cloud Resume Challenge with Terraform: Introduction & Setup 🚀

## Introduction 🌍

The **Cloud Resume Challenge** is a hands-on project designed to build a **real-world cloud application** while showcasing your skills in **AWS, serverless architecture, and automation**. Many implementations of this challenge use AWS SAM or manual setup via the AWS console, but in this series, I will demonstrate how to **build the entire infrastructure using Terraform**. 💡

### **My Journey to Terraform** 🧰

When I first discovered the Cloud Resume Challenge, I was immediately intrigued by the hands-on approach to learning cloud technologies. Having some experience with traditional IT but wanting to transition to a more cloud-focused role, I saw this challenge as the perfect opportunity to showcase my skills.

I chose Terraform over AWS SAM or CloudFormation because:

1. **Multi-cloud flexibility** - While this challenge focuses on AWS, Terraform skills transfer to Azure, GCP, and other providers
2. **Declarative approach** - I find the HCL syntax more intuitive than YAML for defining infrastructure
3. **Industry adoption** - In my research, I found that Terraform was highly sought after in job postings
4. **Strong community** - The extensive module registry and community support made learning easier

This series reflects my personal journey through the challenge, including the obstacles I overcame and the lessons I learned along the way.

### **Why Terraform?** 🛠️

Terraform allows for **Infrastructure as Code (IaC)**, which:

- **Automates** resource provisioning 🤖
- **Ensures consistency** across environments ✅
- **Improves security** by managing configurations centrally 🔒
- **Enables version control** for infrastructure changes 📝

This series assumes **basic knowledge of Terraform** and will focus on **highlighting key Terraform code snippets** rather than full configuration files.

## Project Overview 🏗️

Let's visualize the architecture we'll be building throughout this series:

```
┌───────────┐    ┌──────────┐    ┌──────────┐    ┌────────────┐
│           │    │          │    │          │    │            │
│  Route 53 ├────►CloudFront├────►   S3     │    │    ACM     │
│           │    │          │    │          │    │ Certificate│
└───────────┘    └──────────┘    └──────────┘    └────────────┘
                                                        
                      │                                  
                      ▼                                  
               ┌──────────────┐                          
               │              │                          
               │ API Gateway  │                          
               │              │                          
               └──────────────┘                          
                      │                                  
                      ▼                                  
               ┌──────────────┐     ┌──────────────┐    
               │              │     │              │    
               │    Lambda    ├─────►   DynamoDB   │    
               │              │     │              │    
               └──────────────┘     └──────────────┘    
                      │                                  
                      │                                  
         ┌────────────┴────────────┐                    
         │                         │                    
         ▼                         ▼                    
┌─────────────────┐      ┌──────────────────┐          
│                 │      │                  │          
│  GitHub Actions │      │   GitHub Actions │          
│  (Frontend CI)  │      │   (Backend CI)   │          
│                 │      │                  │          
└─────────────────┘      └──────────────────┘          
```

### **AWS Services Used** ☁️

The project consists of the following AWS components:

- **Frontend:** Static website hosted on **S3** and delivered via **CloudFront**.
- **Backend API:** API Gateway, Lambda, and DynamoDB to track visitor counts.
- **Security:** IAM roles, API Gateway security, and **AWS Certificate Manager (ACM)** for HTTPS 🔐.
- **Automation:** CI/CD with **GitHub Actions** to deploy infrastructure and update website content ⚡.

### **Terraform Module Breakdown** 🧩

To keep the infrastructure modular and maintainable, we will define Terraform modules for each major component:

1. **S3 Module** 📂: Manages the static website hosting.
2. **CloudFront Module** 🌍: Ensures fast delivery and HTTPS encryption.
3. **Route 53 Module** 📡: Handles DNS configuration.
4. **DynamoDB Module** 📊: Stores visitor count data.
5. **Lambda Module** 🏗️: Defines the backend API logic.
6. **API Gateway Module** 🔗: Exposes the Lambda function via a REST API.
7. **ACM Module** 🔒: Provides SSL/TLS certificates for secure communication.

## **Setting Up Terraform** ⚙️

Before deploying any resources, we need to set up **Terraform and backend state management** to store infrastructure changes securely.

### **1. Install Terraform & AWS CLI** 🖥️

Ensure you have the necessary tools installed:

```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

### **2. Configure AWS Credentials Securely** 🔑

Terraform interacts with AWS via credentials. Setting these up securely is crucial to avoid exposing sensitive information.

#### **Setting up AWS Account Structure**

Following cloud security best practices, I recommend creating a proper AWS account structure:

1. **Create a management AWS account** for your organization
2. **Enable Multi-Factor Authentication (MFA)** on the root account
3. **Create separate AWS accounts** for development and production environments
4. **Set up AWS IAM Identity Center (formerly SSO)** for secure access

If you're just getting started, you can begin with a simpler setup:

```bash
# Configure AWS CLI with a dedicated IAM user (not root account)
aws configure

# Test your configuration
aws sts get-caller-identity
```

Set up **IAM permissions** for Terraform by ensuring your IAM user has the necessary policies for provisioning resources. Start with a least privilege approach and add permissions as needed.

### **3. Set Up Remote Backend for Terraform State** 🏢

Using a **remote backend** (such as an **S3 bucket**) prevents local state loss and enables collaboration.

#### **Project Directory Structure**

Here's how I've organized my Terraform project:

```
cloud-resume-challenge/
├── modules/
│   ├── frontend/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── backend/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   └── main.tf
│   └── prod/
│       └── main.tf
├── terraform.tf (backend config)
├── variables.tf
├── outputs.tf
└── main.tf
```

#### **Define the backend in `terraform.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "cloud-resume/state.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  
  required_version = ">= 1.2.0"
}
```

#### **Create S3 Bucket and DynamoDB Table for Backend**

Before you can use an S3 backend, you need to create the bucket and DynamoDB table. I prefer to do this via Terraform as well, using a separate configuration:

```hcl
# backend-setup/main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Run these commands to set up your backend:

```bash
cd backend-setup
terraform init
terraform apply
cd ..
terraform init  # Initialize with the S3 backend
```

## **A Note on Security** 🔒

Throughout this series, I'll be emphasizing security best practices. Some key principles to keep in mind:

1. **Never commit AWS credentials** to your repository
2. **Use IAM roles with least privilege** for all resources
3. **Enable encryption** for sensitive data
4. **Implement proper security groups and network ACLs**
5. **Regularly rotate credentials and keys**

These principles will be applied to our infrastructure as we build it in the upcoming posts.

## **Lessons Learned** 💡

In my initial attempts at setting up the Terraform environment, I encountered several challenges:

1. **State file management**: I initially stored state locally, which caused problems when working from different computers. Switching to S3 backend solved this issue.

2. **Module organization**: I tried several directory structures before settling on the current one. Organizing by component type rather than AWS service made the most sense for this project.

3. **Version constraints**: Not specifying version constraints for providers led to unexpected behavior when Terraform updated. Always specify your provider versions!

## **Next Steps** ⏭️

In the next post, we'll build the **static website infrastructure** with **S3, CloudFront, Route 53, and ACM**. We'll create Terraform modules for each component and deploy them together to host our resume.

### **Developer Mod: Advanced Terraform Techniques** 🚀

If you're familiar with Terraform and want to take this challenge further, consider implementing these enhancements:

1. **Terraform Cloud Integration**: Connect your repository to Terraform Cloud for enhanced collaboration and run history.

2. **Terratest**: Add infrastructure tests using the Terratest framework to validate your configurations.

3. **Custom Terraform Modules**: Create reusable modules and publish them to the Terraform Registry.

4. **Terraform Workspaces**: Use workspaces to manage multiple environments (dev, staging, prod) within the same Terraform configuration.

---

**Up Next:** [Cloud Resume Challenge with Terraform: Deploying the Static Website] 🔗
