# aws-microservices
Built a cloud-native microservices architecture on AWS with VPC, ALB, EC2 Auto Scaling, and RDS for MySQL across multi-AZs. Secured with NAT Gateway, Security Groups, and Secrets Manager.Enabled monitoring via CloudWatch, ensuring high availability, scalability, fault tolerance, and cost efficiency.

![Image Alt](https://github.com/suma419/aws-microservices/blob/883b94d9566ad608799482ae94bbda98cfc5217a/aws_microservices_gITHUB.png)

Architecture
text
VPC (192.168.0.0/16)
│
├── 🌐 Public Subnets (2x) → Internet Gateway, NAT Gateway, Application Load Balancer
│
├── 🔒 Private App Subnets (2x) → Auto Scaling EC2 (PHP app servers)
│
└── 🗄️ Private DB Subnets (2x) → RDS MySQL (Multi-AZ, managed)

Prerequisites
✅ AWS Account with Admin IAM role

✅ AWS CLI installed & configured (aws configure)

✅ Terraform installed (if using IaC)

✅ Basic knowledge of Linux, PHP, MySQL
Setup & Implementation Steps
🔹 1. Create VPC & Networking
bash
# 1. Create VPC
aws ec2 create-vpc --cidr-block 192.168.0.0/16

# 2. Create Public Subnets (one per AZ)
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.1.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.2.0/24 --availability-zone us-east-1b

# 3. Create Private App Subnets
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.3.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.4.0/24 --availability-zone us-east-1b

# 4. Create Private DB Subnets
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.5.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 192.168.6.0/24 --availability-zone us-east-1b

# 5. Create Internet Gateway
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id <VPC_ID> --internet-gateway-id <IGW_ID>
🔹 2. Setup NAT Gateway & Routing
bash
# Allocate Elastic IP for NAT
aws ec2 allocate-address

# Create NAT Gateway in one public subnet
aws ec2 create-nat-gateway --subnet-id <PUBLIC_SUBNET_ID> --allocation-id <EIP_ALLOCATION_ID>

# Update Route Tables appropriately for public and private subnets
🔹 3. Configure Security Groups
bash
# Web SG (for ALB, allow HTTP/HTTPS)
aws ec2 authorize-security-group-ingress \
 --group-id <ALB_SG_ID> --protocol tcp --port 80 --cidr 0.0.0.0/0

# App SG (allow traffic ONLY from ALB)
aws ec2 authorize-security-group-ingress \
 --group-id <APP_SG_ID> --protocol tcp --port 80 --source-group <ALB_SG_ID>

# DB SG (allow MySQL traffic ONLY from App SG)
aws ec2 authorize-security-group-ingress \
 --group-id <DB_SG_ID> --protocol tcp --port 3306 --source-group <APP_SG_ID>
🔹 4. Deploy Amazon RDS (MySQL, Multi-AZ)
bash
aws rds create-db-instance \
 --db-instance-identifier capstone-db \
 --db-instance-class db.t3.micro \
 --engine mysql \
 --allocated-storage 20 \
 --master-username admin \
 --master-user-password <secure-password> \
 --multi-az \
 --db-subnet-group-name <DB_SUBNET_GROUP> \
 --vpc-security-group-ids <DB_SG_ID>
🔑 Store DB password securely in AWS Secrets Manager.

🔹 5. Launch EC2 Auto Scaling PHP Web App
bash
# Create Launch Template with PHP setup
aws ec2 create-launch-template \
 --launch-template-name php-app-template \
 --version-description "v1" \
 --launch-template-data '{
   "ImageId":"ami-xxxxxxx",
   "InstanceType":"t2.micro",
   "SecurityGroupIds":["<APP_SG_ID>"],
   "UserData":"#!/bin/bash
     yum update -y
     amazon-linux-extras enable php8.0
     yum install -y php mysql httpd
     systemctl start httpd
     systemctl enable httpd
     echo \"<?php phpinfo(); ?>\" > /var/www/html/index.php"
 }'

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
 --auto-scaling-group-name php-asg \
 --launch-template LaunchTemplateName=php-app-template,Version=1 \
 --min-size 2 --max-size 5 --desired-capacity 2 \
 --vpc-zone-identifier "<PRIVATE_APP_SUBNETS>"
🔹 6. Configure Application Load Balancer
bash
# Create ALB
aws elbv2 create-load-balancer \
 --name php-alb --subnets <PUBLIC_SUBNETS> --security-groups <ALB_SG_ID>

# Create Target Group
aws elbv2 create-target-group \
 --name php-tg --protocol HTTP --port 80 --vpc-id <VPC_ID>

# Register Targets
aws elbv2 register-targets --target-group-arn <TG_ARN> \
 --targets Id=<EC2_ID_1> Id=<EC2_ID_2>

# Create Listener
aws elbv2 create-listener \
 --load-balancer-arn <ALB_ARN> --protocol HTTP --port 80 \
 --default-actions Type=forward,TargetGroupArn=<TG_ARN>
 7. Monitoring with CloudWatch
Create CloudWatch Alarms for Auto Scaling policies (CPU > 70% = scale out, CPU < 20% = scale in).

Enable Apache/PHP logs with CloudWatch Logs Agent.

🔹 8. Verification
✅ Step 1: Open ALB DNS name in browser → should show PHP info page.
✅ Step 2: Simulate traffic load and check EC2 autoscaling.
✅ Step 3: Stop primary RDS → failover to standby instance.
✅ Step 4: Check Secrets Manager rotation works.

📊 Benefits Achieved
High Availability → Multi-AZ EC2 + Multi-AZ RDS + ALB failover.

Scalability → Auto Scaling group expands/shrinks dynamically.

Security → Private DB/App subnets, SG-controlled communication, Secrets Manager.

Cost Efficiency → NAT + Scaling + Pay-as-you-go model.

Monitoring → CloudWatch alarms & logs.

📂 Repository Structure
text
/infrastructure
   ├── vpc.tf
   ├── ec2.tf
   ├── rds.tf
   ├── alb.tf
   ├── autoscaling.tf
   └── variables.tf
/app
   └── index.php
README.md
🚀 Future Enhancements
Add CI/CD via AWS CodePipeline & CodeDeploy.

Add CloudFront (CDN) + WAF for security & performance.

Add SSL/TLS certificate via ACM for HTTPS.

Use Terraform for full IaC automation.
