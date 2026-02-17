# Resilient-AWS-Architecture-with-Automated-Observability-Incident-Response

## Description
&nbsp;&nbsp;&nbsp;&nbsp;This project demonstrates a production-grade, two-tier AWS architecture designed for high availability, security, and operational excellence. Moving beyond basic deployment, this project focuses on "Day 2 Operations"—implementing automated monitoring, centralized logging, and a proactive incident response framework.

&nbsp;&nbsp;&nbsp;&nbsp;By leveraging Infrastructure as Code (IaC), the environment is fully reproducable and features a "self-healing" logic where infrastructure failures are detected by CloudWatch and reported via SNS, allowing for rapid recovery without manual redeployment.

## Features
**High Availability:** Implements an Auto Scaling Group (ASG) and Application Load Balancer (ALB) across multiple Availability Zones to ensure zero downtime.

**Layered Security:**

&nbsp;&nbsp;&nbsp;&nbsp;**- WAF Integration:** Protects the ALB from common web exploits.

&nbsp;&nbsp;&nbsp;&nbsp;**- Security Group Chaining:** Restricts database access solely to the application tier.

&nbsp;&nbsp;&nbsp;&nbsp;**- Secret Management:** Utilizes AWS Secrets Manager and SSM Parameter Store to eliminate hardcoded credentials.

**Automated Observability:**

&nbsp;&nbsp;&nbsp;&nbsp;**- Centralized Logging:** System and application logs are streamed to CloudWatch Logs.

&nbsp;&nbsp;&nbsp;&nbsp;**- Metric Filters:** Custom filters scan logs for CRITICAL errors to trigger automated alerts.

**Incident Response:** Features a pre-configured CloudWatch Alarm and SNS Topic to notify engineers of database connectivity issues or application failures.

**Global Connectivity:** DNS management and routing via Amazon Route 53.

## Built With
**Infrastructure as Code:** Terraform (HCL)

**Cloud Provider:** AWS (VPC, EC2, RDS, ALB, ASG, WAF, Route 53)

**Security & Config:** AWS Secrets Manager, SSM Parameter Store, IAM

**Monitoring:** CloudWatch Logs, CloudWatch Alarms, SNS

**Scripting:** Bash (User Data for automated server bootstrapping)

## Installation
### Prerequisites
- AWS CLI configured with administrative permissions.

- Terraform (v1.0+) installed.

- An active domain registered in Route 53 (optional, for DNS features).

### Steps
**Clone the Repository:**

```Bash
git clone https://github.com/shawnmosby225/Resilient-AWS-Architecture-with-Automated-Observability-Incident-Response.git
cd Resilient-AWS-Architecture-with-Automated-Observability-Incident-Response
```
**Initialize Terraform:**

```Bash
terraform init
```
**Deploy Infrastructure:**

```Bash
terraform apply
```
## Usage

**Once deployed, the application automates several operational tasks:**

**Automated Setup:** The user_data.sh script automatically installs the web server, database clients, and CloudWatch agents upon boot.

**Health Monitoring:** Navigate to the ALB DNS name (found in Terraform outputs) to view the live application.

**Simulate an Incident:** Intentionally stop the RDS instance or change a secret value to observe the CloudWatch Alarm transition to ALARM state and trigger an SNS email notification.

**Audit Logs:** Review traffic patterns and security blocks via the WAF Logging configurations in the AWS Console.

## Project Structure

**main.tf:** Core provider and networking configuration.

**alb_launchtemp_asg.tf:** Definition of the compute and scaling layer.

**waf_logging.tf:** Security automation and edge protection.

**iam_nd_endpoints.tf:** Principle of Least Privilege (PoLP) roles and VPC Endpoints for secure service communication.

**incident_runbook.txt:** Operational guide for responding to triggered alarms.
