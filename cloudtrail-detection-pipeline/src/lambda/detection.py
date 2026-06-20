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
                suspicious, reason = is_suspicious(records)
                if suspicious:
                    message = build_alert(records, reason)
                    send_alert(message, f"Alert {reason}")
                    logger.info(f"""Alert sent for event: {records['eventName']} from {records['sourceIPAddress']}""")
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
    if not content:
        return {'Records': []}
    try:
        decompressed = gzip.decompress(content)
        return json.loads(decompressed)
    except Exception as e:
        logger.error(f"Error decompressing log: {e}")
        return {'Records': []}


def is_suspicious(record):
    event_name = record.get('eventName', '')
    user_type  = record.get('userIdentity', {}).get('type', '')
    error_code = record.get('errorCode', '')
    mfa_used   = record.get('additionalEventData', {}).get('MFAUsed', 'Yes')

    if event_name in SUSPICIOUS_ACTIONS:
        return True, f"Suspicious action: {event_name}"

    if user_type == 'Root':
        return True, "Root account activity detected"

    if event_name == 'ConsoleLogin' and mfa_used == 'No':
        return True, "Console login without MFA"

    if error_code == 'AccessDenied':
        return True, f"Access denied on {event_name} — possible probing"

    return False, None


def build_alert(record, reason='Suspicious activity detected'):
    return (
        f"{reason}\n"
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