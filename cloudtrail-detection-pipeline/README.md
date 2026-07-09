# Cloud-detection-pipeline


### Problem 
Cloud-native environments continuously generate audit logs through AWS CloudTrail, but these logs are often stored without automated analysis or notification. This creates a gap between event generation and security awareness, forcing engineers to manually inspect audit records after incidents have already occurred. This project demonstrates an event-driven security monitoring pipeline that ingests CloudTrail logs, parses relevant API activity, and publishes security notifications through Amazon SNS to improve operational visibility and accelerate incident response.

---
### Solution

This project implements a serverless, event-driven audit monitoring pipeline that automatically processes AWS CloudTrail logs. CloudTrail records AWS API activity and delivers audit logs to Amazon S3, where newly created log files trigger an AWS Lambda function for parsing and analysis. Relevant security events are then published to Amazon SNS, providing near real-time visibility into cloud activity while reducing the need for manual log inspection.

---

### Architecture
[simple-architectural-diagram](./src/assets/diagram.png)


---

### Tools/AWS Services Used
| Service | Purpose |
|---------|---------|
| Amazon Cloudtrail | Continuous threat detection using ML and threat intel |
| Amazon Lambda | Severless compute function for running code |
| Amazon SNS | Alert delivery via email subscription |
| Amazon S3 | Storage for storing logs |
| Amazon CLoudwatch | A monitoring and Observability service |
| Amazon IAM | Security service that controls AuthN and AuthZ | 
| Amazon KMS | SNS topic encryption and S3 at rest|
| Python | Scripting Language for Lambda code |
| Terraform | Infrastructure as code — full deployment automation |



---

### Prerequisities
- AWS account with appropriate IAM permissions
- Terraform >= 1.0.0 installed
- AWS CLI configured (`aws configure`)
- An email address to receive alerts
---
 
## How to deploy
 
```bash
# clone the repo
git clone https://github.com/recklessbud/cloud-projects
cd cloudtrail-detection-pipeline
 
# initialise Terraform
terraform init
 
# preview what will be created
terraform plan

fill in the neccesary variables
 
# deploy
terraform apply
```

---


### Security Findings and Considerations
This project was scanned with Checkov before deployment to identify infrastructure misconfigurations.

```bash
checkov -d . --framework terraform
```
Some checkov findings after the first scan include;
 - Ensure S3 lifecycle configuration sets period for aborting failed uploads 'main.tf:58-77'
 - Ensure AWS Lambda function is configured to validate code-signing 'main.tf:165-183'
 - Ensure that AWS Lambda function is configured for a Dead Letter Queue(DLQ) 'main.tf:165-183'
 - Check encryption settings for Lambda environmental variable 'main.tf:165-183'
 - the rest found in [](./terraform/checkov-findings.json)

 Checkov Findings fixed are of High severity, the Low Severity are just .***Noise***.. which include;
 - Setting a period for aborting failed uploads in 'main.tf:58-77'
 - configuring lambda to validate code signing.. done on '\main.tf:189-199'


---


### sample email
Change my IP signed into the console
[email-notification](./src/assets/evidence.png)


---
### Cleanup

```bash
# destroy the resources
terraform destroy
```


