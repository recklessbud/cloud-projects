# EventBrigde-SNS-Guardduty


### Problem
Cloud environments are constantly probed. Without automated detection, a threat like an SSH brute force attack, root account usage, or a compromised EC2 instance could go unnoticed for hours or days. Manual log reviews don't scale and human response time is too slow for real security incidents.


### Solution
GuardDuty continuously analyses CloudTrail logs, VPC flow logs, and DNS logs using AWS threat intelligence. When it identifies a finding with severity of Medium or above, EventBridge catches the finding in real time, applies a severity filter, and routes it to an SNS topic as the target. SNS delivers an immediate email alert to the detection engineer.