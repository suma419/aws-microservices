# aws-microservices
Built a cloud-native microservices architecture on AWS with VPC, ALB, EC2 Auto Scaling, and RDS for MySQL across multi-AZs. Secured with NAT Gateway, Security Groups, and Secrets Manager.Enabled monitoring via CloudWatch, ensuring high availability, scalability, fault tolerance, and cost efficiency.

![Image Alt](https://github.com/suma419/aws-microservices/blob/883b94d9566ad608799482ae94bbda98cfc5217a/aws_microservices_gITHUB.png)

# AWS Academy Capstone Project – Cloud Infrastructure for PHP Web Application

## Overview

This project demonstrates how to build and deploy a **highly available, scalable, secure, and cost-effective AWS cloud infrastructure** for hosting a **PHP web application** backed by a **MySQL RDS database**. The architecture uses best practices to ensure fault tolerance, automation, and easy maintenance in production.

---

## Prerequisites

Before you begin, ensure the following:

- **AWS Account** with sufficient permissions (Admin or equivalent IAM role)
- **AWS CLI** installed and configured on your machine (`aws configure`)
- **Terraform** installed if you want to use Infrastructure as Code (optional)
- Basic familiarity with:
  - Linux commands
  - PHP application deployment
  - MySQL or relational databases
- Access to the PHP application source code (can be a simple PHP info page for testing)

---

## Implementation Steps Explained

### 1. Create VPC and Networking Setup

- Define a **VPC with CIDR block 192.168.0.0/16** to isolate your infrastructure.
- Create six /24 subnets spread across two Availability Zones (AZs):
  - 2 Public subnets for Internet Gateway, NAT Gateway, and the Application Load Balancer.
  - 2 Private subnets for application servers (EC2 instances).
  - 2 Private subnets for the database (RDS instances).
- Attach an **Internet Gateway** to your VPC to allow internet access to public subnets.
  
This setup ensures **network segmentation and high availability** across AZs.

### 2. Setup NAT Gateway and Routing

- Allocate an **Elastic IP** for the NAT Gateway.
- Deploy a NAT Gateway inside a public subnet for routing outbound internet traffic from private instances.
- Adjust route tables for public/private subnets to ensure correct traffic flow and security.

This allows your private subnets (app servers and DB) to securely access the internet for updates without exposing them publicly.

### 3. Configure Security Groups

- Create a security group for the **Application Load Balancer (ALB)** allowing HTTP (80) and HTTPS (443) traffic from anywhere.
- Create a security group for **App servers** that only accepts HTTP (80) from the ALB security group.
- Create a security group for **RDS MySQL** that only accepts traffic on port 3306 from the App server security group.

This **ensures minimal network exposure and secure, restricted access** between components.

### 4. Deploy Amazon RDS MySQL (Multi-AZ)

- Provision a **Multi-AZ RDS MySQL instance** for high availability and automatic failover.
- The database credentials should be stored and rotated securely using **AWS Secrets Manager**.
- The RDS should run within the private DB subnets.

This delivers a fully managed, fault-tolerant database layer vital for production apps.

### 5. Launch EC2 Auto Scaling Group with PHP App

- Create a **Launch Template** for EC2 instances running Amazon Linux with PHP, Apache, and MySQL clients installed.
- Use `UserData` scripts to automate initial instance setup and deploy your PHP application.
- Define an **Auto Scaling Group** across private app subnets to automatically scale in/out based on traffic.

This allows your application servers to dynamically adjust capacity per workload for cost efficiency and reliability.

### 6. Configure Application Load Balancer (ALB)

- Setup an Application Load Balancer in the public subnets to distribute incoming HTTP traffic across EC2 instances.
- Create a Target Group pointing to the EC2 instances registered automatically by the Auto Scaling Group.
- Setup health checks to route traffic only to healthy instances.

This provides **fault tolerance and seamless user experience** by distributing traffic efficiently.

### 7. Monitoring and Alerts using CloudWatch

- Configure **CloudWatch Alarms** to monitor EC2 CPU usage, scaling thresholds, and RDS health.
- Install and configure **CloudWatch Logs Agent** on EC2 for Apache and application logs collection.
- Alerts can trigger autoscaling or notify administrators proactively.

This enables you to maintain performance and operational visibility.

### 8. Verification and Testing

- Visit the Application Load Balancer's DNS endpoint; it should display your PHP app's output (e.g., `phpinfo()`).
- Simulate traffic and monitor automatic scaling.
- Test RDS Multi-AZ failover by forcing failover scenarios.
- Verify Secrets Manager credential rotation capability.

Ensuring your infrastructure behaves as expected under real conditions.

---

## Summary

| Step | Description                         | Purpose                                      |
|-------|-----------------------------------|---------------------------------------------|
| 1     | VPC and subnet setup              | Network isolation and high availability     |
| 2     | NAT and routing                   | Secure internet access from private subnets |
| 3     | Security Groups                  | Controlled access and network security       |
| 4     | RDS Multi-AZ deployment           | Fault-tolerant managed database              |
| 5     | EC2 Auto Scaling with PHP         | Scalable web server layer                     |
| 6     | Application Load Balancer          | Load distribution and fault tolerance        |
| 7     | Monitoring with CloudWatch         | Operational visibility and alerting          |
| 8     | Verification and testing           | Validate setup                                 |

---

## Next Steps and Enhancements

- Automate entire setup with Terraform or CloudFormation.
- Add **CI/CD pipelines** (AWS CodePipeline/CodeDeploy).
- Integrate **CloudFront CDN** for global caching and HTTPS.
- Implement **AWS WAF** for security at the edge.
- Enable backup and recovery strategies on RDS and application data.

---



