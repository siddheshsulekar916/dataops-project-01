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

# 4. Database & Bronze Table
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

    columns { name = "log_id"       type = "int"    }
    columns { name = "timestamp"    type = "string" }
    columns { name = "threat_level" type = "string" }
  }
}

# 5. IAM Permissions for Glue
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

# 6. The ETL Job
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

# 7. The Crawler
resource "aws_glue_crawler" "silver_crawler" {
  database_name = aws_glue_catalog_database.security_db.name
  name          = "siddhesh-silver-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/silver/"
  }
}

# --- NEW FOR TODAY: AUTOMATION LAYER ---

# 8. Lambda Role & Permissions
resource "aws_iam_role" "lambda_role" {
  name = "DataOpsLambdaTriggerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_glue_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 9. Packaging and Creating the Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "trigger_glue_job.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "s3_trigger_lambda" {
  filename         = "lambda_function.zip"
  function_name    = "siddhesh-s3-glue-trigger"
  role             = aws_iam_role.lambda_role.arn
  handler          = "trigger_glue_job.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
}

# 10. Granting S3 permission to call Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_lake.arn
}

# 11. S3 Event Notification (The actual Trigger)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_lake.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "bronze/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}