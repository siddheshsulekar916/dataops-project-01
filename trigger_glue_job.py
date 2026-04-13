import boto3

def lambda_handler(event, context):
    glue = boto3.client('glue')
    
    # Replace with your actual Glue Job Name
    job_name = 'siddhesh-parquet-transform'
    
    try:
        response = glue.start_job_run(JobName=job_name)
        return {
            'statusCode': 200,
            'body': f"Started Glue Job: {job_name}"
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': str(e)
        }