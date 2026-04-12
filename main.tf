# 1. Define the Provider
provider "aws" {
  region = "us-east-1" 
}

# 2. The Data Lake (Bronze Layer)
resource "aws_s3_bucket" "data_lake" {
  bucket = "siddhesh-dataops-lake-2026-v1" # Must be globally unique
}

# 3. The Database (Gold Layer)
resource "aws_glue_catalog_database" "security_db" {
  name = "security_logs_db"
}

# 4. IAM Role (Security is part of Ops!)
resource "aws_iam_role" "glue_role" {
  name = "DataOpsGlueRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}