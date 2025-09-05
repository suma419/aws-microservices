#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------
# AWS Capstone Project Post-Setup (7–12)
# Wires routes, attaches ASG, deploys app,
# sets scaling policy, prints ALB URL.
# --------------------------------------

REGION="${REGION:-us-east-1}"
VPC_CIDR="${VPC_CIDR:-192.168.0.0/16}"

ASG_NAME="${ASG_NAME:-php-asg}"
TG_NAME="${TG_NAME:-php-tg}"
ALB_NAME="${ALB_NAME:-php-alb}"
LT_NAME="${LT_NAME:-php-app-template}"
DB_ID="${DB_ID:-capstone-db}"

DB_USERNAME="${DB_USERNAME:-admin}"
DB_PASSWORD="${DB_PASSWORD:-ChangeMe123!}"

INDEX_PHP_PATH="${INDEX_PHP_PATH:-./index.php}"

echo "🔎 Discovering resources in $REGION"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=cidr-block,Values="$VPC_CIDR" --query 'Vpcs[0].VpcId' --output text --region "$REGION")

SUBNET_PUBLIC1=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.1.0/24 --query 'Subnets[0].SubnetId' --output text)
SUBNET_PUBLIC2=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.2.0/24 --query 'Subnets[0].SubnetId' --output text)
SUBNET_PRIVATE_APP1=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.3.0/24 --query 'Subnets[0].SubnetId' --output text)
SUBNET_PRIVATE_APP2=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.4.0/24 --query 'Subnets[0].SubnetId' --output text)
SUBNET_PRIVATE_DB1=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.5.0/24 --query 'Subnets[0].SubnetId' --output text)
SUBNET_PRIVATE_DB2=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=192.168.6.0/24 --query 'Subnets[0].SubnetId' --output text)

IGW_ID=$(aws ec2 describe-internet-gateways --region "$REGION" --filters Name=attachment.vpc-id,Values="$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
NAT_GW_ID=$(aws ec2 describe-nat-gateways --region "$REGION" --filter Name=subnet-id,Values="$SUBNET_PUBLIC1" Name=state,Values=available --query 'NatGateways[0].NatGatewayId' --output text)

TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text)
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
LT_ID=$(aws ec2 describe-launch-templates --region "$REGION" --filters Name=launch-template-name,Values="$LT_NAME" --query 'LaunchTemplates[0].LaunchTemplateId' --output text)

# ---- 7) Route Tables ----
echo "🛣️  Configuring route tables ..."
PUBLIC_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$PUBLIC_RT" --region "$REGION" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUBLIC_RT" --subnet-id "$SUBNET_PUBLIC1" --region "$REGION" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUBLIC_RT" --subnet-id "$SUBNET_PUBLIC2" --region "$REGION" >/dev/null

APP_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$APP_RT" --region "$REGION" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$APP_RT" --subnet-id "$SUBNET_PRIVATE_APP1" --region "$REGION" >/dev/null
aws ec2 associate-route-table --route-table-id "$APP_RT" --subnet-id "$SUBNET_PRIVATE_APP2" --region "$REGION" >/dev/null

DB_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 associate-route-table --route-table-id "$DB_RT" --subnet-id "$SUBNET_PRIVATE_DB1" --region "$REGION" >/dev/null
aws ec2 associate-route-table --route-table-id "$DB_RT" --subnet-id "$SUBNET_PRIVATE_DB2" --region "$REGION" >/dev/null
echo "✅ Route tables configured."

# ---- 8) Attach ASG to TG + Health Checks ----
echo "🎯 Attaching ASG to target group & setting health checks ..."
aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name "$ASG_NAME" --target-group-arns "$TG_ARN" --region "$REGION"
aws elbv2 modify-target-group --region "$REGION" --target-group-arn "$TG_ARN" --health-check-path /index.php --health-check-interval-seconds 30 --matcher HttpCode=200
echo "✅ ASG attached; health checks configured."

# ---- 9) Wait for RDS; store creds (optional) ----
echo "⏳ Waiting for RDS ($DB_ID) to be available ..."
aws rds wait db-instance-available --db-instance-identifier "$DB_ID" --region "$REGION"
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" --query 'DBInstances[0].Endpoint.Address' --output text)
echo "🗄️  RDS endpoint: $RDS_ENDPOINT"

if ! aws secretsmanager describe-secret --secret-id capstone-db-credentials --region "$REGION" >/dev/null 2>&1; then
  aws secretsmanager create-secret --region "$REGION" --name capstone-db-credentials --secret-string "{"username":"$DB_USERNAME","password":"$DB_PASSWORD","host":"$RDS_ENDPOINT","db":"capstone_db"}" >/dev/null
  echo "🔐 Stored DB creds in Secrets Manager: capstone-db-credentials"
fi

# ---- 9b) Upload index.php to S3 & roll to ASG ----
if [ ! -f "$INDEX_PHP_PATH" ]; then
  echo "❌ index.php not found at $INDEX_PHP_PATH"
  exit 1
fi

BUCKET="capstone-php-app-$(date +%s)"
aws s3 mb "s3://$BUCKET" --region "$REGION" >/dev/null
aws s3 cp "$INDEX_PHP_PATH" "s3://$BUCKET/index.php" --region "$REGION" >/dev/null
echo "☁️  Uploaded index.php to s3://$BUCKET/index.php"

NEW_LT_VERSION=$(aws ec2 create-launch-template-version --region "$REGION"   --launch-template-id "$LT_ID"   --source-version 1   --launch-template-data "{
    "UserData": "$(echo '#!/bin/bash
yum update -y
amazon-linux-extras enable php8.0
yum install -y php mysql httpd awscli -y
systemctl start httpd
systemctl enable httpd
aws s3 cp s3://$BUCKET/index.php /var/www/html/index.php
sed -i "s|your-rds-endpoint.amazonaws.com|'"$RDS_ENDPOINT"'|g" /var/www/html/index.php
sed -i "s|your_db_password|'"$DB_PASSWORD"'|g" /var/www/html/index.php
sed -i "s|capstone_db|capstone_db|g" /var/www/html/index.php
' | base64)"
  }" --query 'LaunchTemplateVersion.VersionNumber' --output text)
echo "🧩 New Launch Template version: $NEW_LT_VERSION"

aws autoscaling update-auto-scaling-group --region "$REGION" --auto-scaling-group-name "$ASG_NAME" --launch-template LaunchTemplateId="$LT_ID",Version="$NEW_LT_VERSION"
aws autoscaling start-instance-refresh --auto-scaling-group-name "$ASG_NAME" --region "$REGION" >/dev/null
echo "♻️  Instance refresh started."

# ---- 10) ALB DNS & test hint ----
ALB_DNS=$(aws elbv2 describe-load-balancers --region "$REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].DNSName' --output text)
echo "🌐 ALB DNS: http://$ALB_DNS"
echo "Run: curl -I http://$ALB_DNS/index.php (when targets are healthy)"

# ---- 11) Target tracking scaling policy (optional) ----
aws autoscaling put-scaling-policy --region "$REGION" --auto-scaling-group-name "$ASG_NAME" --policy-name cpu50-targettracking --policy-type TargetTrackingScaling --target-tracking-configuration '{
  "PredefinedMetricSpecification": { "PredefinedMetricType": "ASGAverageCPUUtilization" },
  "TargetValue": 50.0
}' >/dev/null
echo "📈 Scaling policy attached."

# ---- 12) HTTPS instructions ----
cat <<'NOTE'

🔒 To enable HTTPS in production:
1) Request/validate an ACM certificate in the SAME region for your domain.
2) Create a 443 listener on the ALB with that certificate:
   aws elbv2 create-listener      --load-balancer-arn $ALB_ARN      --protocol HTTPS --port 443      --certificates CertificateArn=<CERT_ARN>      --default-actions Type=forward,TargetGroupArn=$TG_ARN

NOTE

echo "✅ Steps 7–12 complete."
