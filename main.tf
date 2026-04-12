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

resource "aws_glue_catalog_table" "security_logs_table" {
  name          = "processed_logs"
  database_name = aws_glue_catalog_database.security_db.name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/bronze/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
    }

    columns {
      name = "log_id"
      type = "int"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "threat_level"
      type = "string"
    }
  }
}