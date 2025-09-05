#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------
# AWS Capstone Project Setup (Steps 1–6)
# PHP Web App + MySQL on AWS
# --------------------------------------

REGION="${REGION:-us-east-1}"
CIDR_BLOCK="${CIDR_BLOCK:-192.168.0.0/16}"

# Replace these before running
DB_USERNAME="${DB_USERNAME:-admin}"
DB_PASSWORD="${DB_PASSWORD:-ChangeMe123!}"
AMI_ID="${AMI_ID:-ami-xxxxxxxx}"        # e.g., Amazon Linux 2 AMI in your region
KEY_PAIR="${KEY_PAIR:-my-keypair-name}"  # existing EC2 key pair

echo "Region: $REGION"

# ---- Step 1: VPC & Subnets ----
VPC_ID=$(aws ec2 create-vpc --cidr-block "$CIDR_BLOCK" --region "$REGION" --query 'Vpc.VpcId' --output text)
echo "✅ VPC: $VPC_ID"

SUBNET_PUBLIC1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.1.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
SUBNET_PUBLIC2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.2.0/24 --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)
SUBNET_PRIVATE_APP1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.3.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
SUBNET_PRIVATE_APP2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.4.0/24 --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)
SUBNET_PRIVATE_DB1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.5.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
SUBNET_PRIVATE_DB2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 192.168.6.0/24 --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)

IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION"
echo "✅ IGW: $IGW_ID"

# ---- Step 2: NAT & EIP ----
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --region "$REGION" --query 'AllocationId' --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id "$SUBNET_PUBLIC1" --allocation-id "$EIP_ALLOC" --region "$REGION" --query 'NatGateway.NatGatewayId' --output text)
echo "✅ NAT GW: $NAT_GW_ID (will take a minute to become available)"

# ---- Step 3: Security Groups ----
ALB_SG=$(aws ec2 create-security-group --group-name alb-sg --description "ALB SG" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$REGION"

APP_SG=$(aws ec2 create-security-group --group-name app-sg --description "App SG" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port 80 --source-group "$ALB_SG" --region "$REGION"

DB_SG=$(aws ec2 create-security-group --group-name db-sg --description "DB SG" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port 3306 --source-group "$APP_SG" --region "$REGION"
echo "✅ Security Groups: $ALB_SG $APP_SG $DB_SG"

# ---- Step 4: RDS (MySQL Multi-AZ) ----
aws rds create-db-subnet-group   --db-subnet-group-name capstone-db-subnet   --db-subnet-group-description "DB Subnet Group"   --subnet-ids "$SUBNET_PRIVATE_DB1" "$SUBNET_PRIVATE_DB2"   --region "$REGION"

aws rds create-db-instance   --db-instance-identifier capstone-db   --db-instance-class db.t3.micro   --engine mysql   --allocated-storage 20   --master-username "$DB_USERNAME"   --master-user-password "$DB_PASSWORD"   --multi-az   --db-subnet-group-name capstone-db-subnet   --vpc-security-group-ids "$DB_SG"   --region "$REGION"
echo "✅ RDS MySQL creation started"

# ---- Step 5: Launch Template & Auto Scaling (PHP) ----
LT_ID=$(aws ec2 create-launch-template   --launch-template-name php-app-template   --version-description "v1"   --launch-template-data "{
    "ImageId": "$AMI_ID",
    "InstanceType": "t2.micro",
    "KeyName": "$KEY_PAIR",
    "SecurityGroupIds": ["$APP_SG"],
    "UserData": "$(echo '#!/bin/bash
yum update -y
amazon-linux-extras enable php8.0
yum install -y php mysql httpd
systemctl start httpd
systemctl enable httpd
echo "<?php phpinfo(); ?>" > /var/www/html/index.php
' | base64)"
  }"   --region "$REGION"   --query 'LaunchTemplate.LaunchTemplateId' --output text)

aws autoscaling create-auto-scaling-group   --auto-scaling-group-name php-asg   --launch-template LaunchTemplateId="$LT_ID",Version=1   --min-size 2 --max-size 5 --desired-capacity 2   --vpc-zone-identifier "$SUBNET_PRIVATE_APP1,$SUBNET_PRIVATE_APP2"   --region "$REGION"
echo "✅ ASG created (php-asg), LT: $LT_ID"

# ---- Step 6: Application Load Balancer ----
ALB_ARN=$(aws elbv2 create-load-balancer   --name php-alb   --subnets "$SUBNET_PUBLIC1" "$SUBNET_PUBLIC2"   --security-groups "$ALB_SG"   --region "$REGION"   --query 'LoadBalancers[0].LoadBalancerArn' --output text)

TG_ARN=$(aws elbv2 create-target-group   --name php-tg   --protocol HTTP --port 80   --vpc-id "$VPC_ID"   --region "$REGION"   --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 create-listener   --load-balancer-arn "$ALB_ARN"   --protocol HTTP --port 80   --default-actions Type=forward,TargetGroupArn="$TG_ARN"   --region "$REGION"

echo "✅ ALB + TG created"
echo "👉 Next: run post_setup_7_12.sh to wire routes, attach ASG to TG, deploy app, and print ALB URL."
