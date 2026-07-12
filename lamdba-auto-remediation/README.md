# Lambda-auto-remediation

### Problem
Cloud security findings from Amazon GuardDuty and AWS Config often require manual investigation and remediation, increasing response times and leaving vulnerable resources exposed. Organizations need an automated solution that can detect security findings, remediate common issues, and notify security teams in near real time.


### Solution
Cloud security findings from Amazon GuardDuty and AWS Config often require manual investigation and remediation, increasing response times and leaving vulnerable resources exposed. Organizations need an automated solution that can detect security findings, remediate common issues, and notify security teams in near real time.

---
### Architecture
[simple architecture](./src/assests/archi.png)

---
### Tools / AWS services Used
### Tools/AWS Services Used
| Service | Purpose |
|---------|---------|
| Amazon Lambda | Severless compute function for running code |
| Amazon SNS | Alert delivery via email subscription |
| Amazon S3 | Storage for storing logs |
| Amazon CLoudwatch | A monitoring and Observability service |
| Amazon IAM | Security service that controls AuthN and AuthZ | 
| Amazon KMS | SNS topic encryption and S3 at rest|
| Amazon Config| record AWS configuration and evaluates them against pre-defined rule |
| Amazon Guardduty| Intelligent security analyst that detects suspicious activities|
| Amazon EventBridge| Severless event bus that filters and route events to target |
| Python | Scripting Language for Lambda code |
| Terraform | Infrastructure as code — full deployment automation |

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
cd lambda-auto-remediation

cd terraform 
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
This project was scanned with Trivy before deployment to identify infrastructure misconfigurations.

```bash
trivy config --severity HIGH terraform/
```
Trivy finding include:
- Topics should be encrypted with customer managed KMS keys and not default AWS managed keys, in order to allow granular key management.

Solution:
-  Encryted SNS with KMS Keys fixed on line 98



### sample email
[remediated-alert](./src/assests/image.png)


---
### Cleanup

```bash
# destroy the resources
terraform destroy
```