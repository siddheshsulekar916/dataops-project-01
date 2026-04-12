# 1. Define the Provider
provider "aws" {
  region = "us-east-1" 
}

# 2. The Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "siddhesh-dataops-lake-2026-v1"
}

# 3. Create the 'bronze' folder automatically so you don't have to do it manually
resource "aws_s3_object" "bronze_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "bronze/"
  content_type = "application/x-directory"
}

# 4. The Database
resource "aws_glue_catalog_database" "security_db" {
  name = "security_logs_db"
}

# 5. The Table with Header Skip Logic
resource "aws_glue_catalog_table" "security_logs_table" {
  name          = "processed_logs"
  database_name = aws_glue_catalog_database.security_db.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    # Points to the folder we created above
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/bronze/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar"          = ","
        "skip.header.line.count" = "1" # CRITICAL: Skips the 'log_id,timestamp' text row
      }
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