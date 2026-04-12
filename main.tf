# 1. Define the Provider
provider "aws" {
  region = "us-east-1" 
}

# 2. The Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "siddhesh-dataops-lake-2026-v1"
}

# 3. Folder Architecture
resource "aws_s3_object" "bronze_folder" {
  bucket       = aws_s3_bucket.data_lake.id
  key          = "bronze/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "silver_folder" {
  bucket       = aws_s3_bucket.data_lake.id
  key          = "silver/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "scripts_folder" {
  bucket       = aws_s3_bucket.data_lake.id
  key          = "scripts/"
  content_type = "application/x-directory"
}

# 4. Database & Bronze Table (Manual)
resource "aws_glue_catalog_database" "security_db" {
  name = "security_logs_db"
}

resource "aws_glue_catalog_table" "security_logs_table" {
  name          = "processed_logs"
  database_name = aws_glue_catalog_database.security_db.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/bronze/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar"          = ","
        "skip.header.line.count" = "1"
      }
    }

    # Fixed syntax: Multi-line blocks for columns
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

# 5. IAM Permissions
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

resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 6. The ETL Job (Bronze -> Silver)
resource "aws_glue_job" "parquet_transformation" {
  name     = "siddhesh-parquet-transform"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.data_lake.bucket}/scripts/transform_to_parquet.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
  }
}

# 7. THE CRAWLER (Replaces the silver_logs_table)
resource "aws_glue_crawler" "silver_crawler" {
  database_name = aws_glue_catalog_database.security_db.name
  name          = "siddhesh-silver-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/silver/"
  }
}