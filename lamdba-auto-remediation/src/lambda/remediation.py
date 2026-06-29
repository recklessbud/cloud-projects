import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)



ec2_client = boto3.client('ec2')
s3_client = boto3.client("s3")
iam_client = boto3.client('iam')
sns_client = boto3.client('sns')


SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


def lambda_handler(event, context):
    logger.info(f'Received event: {json.dumps(event)}')

    details = event.get('detail', {})
    source = event.get('source', '')
    detail_type = event.get('detail_type', '')


    try:
        if source == 'aws.guardduty':
            handle_guardduty(details)
        elif source == 'aws.config':
            config_handler(details)

        elif source == "custom.remediation":
            scan_and_remediate_all()
    except Exception as e:
        logger.error(f"Error processing event: {e}")
        send_alert(
            subject="❌ Remediation Failed",
            message=f"Remediation failed with error:\n{str(e)}\n\nEvent:\n{json.dumps(event, indent=2)}"
        )
        raise

    return {
        'statusCode': 200,
        'body': 'Remediation complete'
    }



def handle_guardduty(detail):
    finding_type = detail.get('type', '')
    severity = detail.get('severity', 0)
    resource = detail.get('resource', {})


    logger.info(f"GuardDuty finding: {finding_type} severity: {severity}")

    if severity < 4:
        logger.info("Low severity-skipping remediation")
        return
    
    if 'SSHBruteForce' in finding_type or 'RDPBruteForce' in finding_type:
        instance_id = resource.get('instanceDetails', {}).get('instanceId')
        if instance_id:
            isolate_ec2(instance_id, finding_type)

    elif 'PortProbe' in finding_type:
        instance_id = resource.get('instanceDetails', {}).get('instanceId')
        if instance_id:
            scan_instance_security_groups(instance_id)

    elif 'RootCredentialUsage' in finding_type:
        send_alert(
            subject="🚨 ROOT ACCOUNT USED",
            message=f"Root account activity detected!\n\nFinding details:\n{json.dumps(detail, indent=2)}"
        )


    else:
        send_alert(
            subject=f"⚠️ GuardDuty Finding: {finding_type}",
            message=f"Unhandled GuardDuty finding:\n\nType: {finding_type}\nSeverity: {severity}\n\n{json.dumps(detail, indent=2)}"
        )




def config_handler(detail):
    config_rule  = detail.get('configRuleName', '')
    resource_id  = detail.get('resourceId', '')
    resource_type = detail.get('resourceType', '')
    status       = detail.get('newEvaluationResult', {}).get('complianceType', '')


    if status != "NON_COMPLAINT":
        logger.info("Aint no complaints")
        return
    
    logger.info(f"Config rule breach: {config_rule} on {resource_type} {resource_id}")

    if 'restricted-ssh' in config_rule or 'ssh' in config_rule.lower():
        remediate_security_groups(resource_id)

    elif 's3' in config_rule.lower() and 'public' in config_rule.lower():
        remediate_s3_public_access(resource_id)

    # elif 'mfa' in config_rule.lower():
    #     remediate_iam_no_mfa(resource_id)

    else:
        send_alert(
            subject=f"⚠️ Config Breach: {config_rule}",
            message=f"Unhandled Config rule breach:\n\nRule: {config_rule}\nResource: {resource_type} {resource_id}"
        )


def remediate_security_groups(sg_id):
    logger.info(f"Checking security group: {sg_id}")

    try:
        response =  ec2_client.describe_security_groups(GroupIds=[sg_id])
        sg       = response['SecurityGroups'][0]
        sg_name  = sg['GroupName']
        revoked  = []


        for rule in sg['IpPermissions']:
            from_port = rule.get('FromPort', 0)
            to_port   = rule.get('ToPort', 0)     

            for ip_range in rule.get('IpRanges', []):
                cidr = ip_range.get('CidrIp', '') 

                if cidr in ['0.0.0.0/0', '::/0'] and from_port in [22, 3389]:
                    logger.info(f"Revoking port {from_port} on {sg_id}")

                    ec2_client.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=[rule])

                    revoked.append({
                        'port': from_port,
                        'cidr': cidr,
                        'sg_id': sg_id,
                        'sg_name': sg_name
                    })

        if revoked:
            message = build_sg_alert(sg_id, sg_name, revoked)
            send_alert(
                subject=f"✅ Auto-Remediated: Open port on {sg_name}",
                message=message
            )
        else:
            logger.info(f"No dangerous rules found on {sg_id}")

    except Exception as e:
        logger.error(f"Error remediating SG {sg_id}: {e}")
        raise



def scan_instance_security_groups(instance_id):
    logger.info(f"Scanning SGs for instance: {instance_id}")

    response = ec2_client.describe_instances(InstanceIds=[instance_id])
    reservations = response['Reservations']

    for reservation in reservations:
        for instance in reservation['Instances']:
            for sg in instance['SecurityGroups']:
                remediate_security_groups(sg['GroupId'])   


def isolate_ec2(instance_id, finding_type):
    logger.info(f"EC2 isolation triggered for {instance_id}")

    send_alert(
        subject=f"🚨 Compromised EC2: {instance_id}",
        message=(
            f"GuardDuty detected: {finding_type}\n\n"
            f"Instance: {instance_id}\n\n"
            f"Recommended actions:\n"
            f"1. Isolate instance by replacing SG with restrictive one\n"
            f"2. Take EBS snapshot for forensics\n"
            f"3. Investigate CloudTrail for activity\n"
            f"4. Terminate if confirmed compromised"
        )
    )



def remediate_s3_public_access(bucket):
    logger.info(f"blocking public access on bucket: {bucket}")

    try:
        s3_client.put_public_access_block(
            Bucket=bucket,
            PublicAccessBlockConfiguration = {
                'BlockPublicAcls'      : True,
                'IgnorePublicAcls'     : True,
                'BlockPublicPolicy'    : True,
                'RestrictPublicBuckets': True
            }
        )

        send_alert(
            subject=f"✅ Auto-Remediated: S3 bucket {bucket} made private",
            message=(
                f"S3 bucket was detected as public and has been secured.\n\n"
                f"Bucket: {bucket}\n"
                f"Action: All public access blocked\n\n"
                f"Please review bucket policy and ACLs manually."
            )
        )
        logger.info(f"Public access blocked on {bucket}")
    except Exception as e:
        logger.error(f"Error remediating bucket pub access: {bucket}: {e}")
        raise
        



def build_sg_alert(sg_id, sg_name, revoked_rules):
    rules_text = "\n".join([
        f"  - Port {r['port']} open to {r['cidr']} — REVOKED"
        for r in revoked_rules
    ])

    return (
        f"Security group automatically remediated.\n\n"
        f"Security Group : {sg_name} ({sg_id})\n"
        f"Rules revoked  :\n{rules_text}\n\n"
        f"Please review the security group and investigate "
        f"why this rule was added."
    )


def send_alert(subject, message):
    try:
        sns_client.publish(
            TopicArn = SNS_TOPIC_ARN,
            Subject  = subject[:100],
            Message  = message
        )
        logger.info(f"Alert sent: {subject}")
    except Exception as e:
        logger.error(f"Failed to send SNS alert: {e}")




def scan_and_remediate_all():
    logger.info("Running full account security scan")

    response = ec2_client.describe_security_groups(
        Filters=[{
            'Name'  : 'ip-permission.cidr',
            'Values': ['0.0.0.0/0']
        }]
    )

    flagged = 0
    for sg in response['SecurityGroups']:
        sg_id   = sg['GroupId']
        sg_name = sg['GroupName']

        for rule in sg['IpPermissions']:
            from_port = rule.get('FromPort', 0)
            for ip in rule.get('IpRanges', []):
                if ip.get('CidrIp') == '0.0.0.0/0' and from_port in [22, 3389]:
                    flagged += 1
                    remediate_security_groups(sg_id)

    if flagged == 0:
        logger.info("Full scan complete — no issues found")
    else:
        logger.info(f"Full scan complete — remediated {flagged} security groups")
