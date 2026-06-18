import boto3
import json
import gzip
import logging
import urllib.parse
import os


logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')


SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
SUSPICIOUS_ACTIONS = os.environ['SUSPICIOUS_ACTIONS'].split(',')


def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')

        content = download_log(bucket, key)
        decompressed = decompress_log(content)

        for records in decompressed.get('Records', []):
            try:
                event_name = records['eventName']
                event_source = records['eventSource']

                if is_suspicious(event_name, event_source):
                    message = build_alert(records)
                    send_alert(message, 'Suspicious activity detected')
                    logger.info(f"""Alert sent for {event_name} ({event_source})""")
            except Exception as e:
                logger.error(f"Error processing record: {e}")

    return {
        'statusCode': 200,
        'body': 'Success'
    }


def download_log(bucket, key):
    try:
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        return obj['Body'].read()
    except Exception as e:
        logger.error(f"Error downloading log: {e}")
        return None



def decompress_log(content):
    decompressed = gzip.decompress(content)
    return json.loads(decompressed)


def is_suspicious(event_name, event_source):
    if event_name in SUSPICIOUS_ACTIONS:
        return True

    return False


def build_alert(record):
    return (
        f"Suspicious activity detected!\n"
        f"Time: {record['eventTime']}\n"
        f"Event: {record['eventName']} ({record['eventSource']})\n"
        f"User: {record['userIdentity'].get('arn', 'unknown')}\n"
        f"Source IP: {record['sourceIPAddress']}\n"
        f"Region: {record['awsRegion']}"
    )


def send_alert(message, subject):
    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=message,
        Subject=subject
    )