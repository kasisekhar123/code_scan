import boto3
import json
from io import BytesIO
import os
import pandas as pd

def lambda_handler(event, context):
    client = boto3.client('s3')
    print("Fetching the event data...")
    print("------------------------------------------")
    s3_Bucket_Name = event["Records"][0]["s3"]["bucket"]["name"]
    s3_File_Name = event['Records'][0]['s3']['object']['key']
    print(s3_Bucket_Name)
    print(s3_File_Name)
    try:
        response = client.get_object(Bucket=s3_Bucket_Name, Key=s3_File_Name)
        data = response['Body'].read()
        print(data)
        df = pd.read_csv(BytesIO(data))
        print(df)

        # Write DataFrame to Parquet
        #df.to_parquet("output.parquet")

        # Upload Parquet file to S3
        s3_parquet_key = "/tmp"+"csv_to_parquet_output.parquet"
        df.to_parquet(s3_parquet_key)
        client.put_object(Body="sjndksndkjns", Bucket=s3_Bucket_Name, Key=s3_parquet_key)

        return {
            'statusCode': 200,
            'body': json.dumps('Success')
        }
    except Exception as e:
        print("Error:", e)
        return {
            'statusCode': 500,
            'body': json.dumps('Error retrieving object from S3')
        }