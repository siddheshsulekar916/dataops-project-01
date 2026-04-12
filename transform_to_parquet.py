import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Read from the Glue Catalog (Bronze Table)
datasource = glueContext.create_dynamic_frame.from_catalog(
    database = "security_logs_db", 
    table_name = "processed_logs"
)

# Write to S3 in Parquet format (Silver Zone)
glueContext.write_dynamic_frame.from_options(
    frame = datasource,
    connection_type = "s3",
    connection_options = {"path": "s3://siddhesh-dataops-lake-2026-v1/silver/"},
    format = "parquet"
)