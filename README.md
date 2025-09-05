# aws-microservices
Built a cloud-native microservices architecture on AWS with VPC, ALB, EC2 Auto Scaling, and RDS for MySQL across multi-AZs. Secured with NAT Gateway, Security Groups, and Secrets Manager.Enabled monitoring via CloudWatch, ensuring high availability, scalability, fault tolerance, and cost efficiency.

![Image Alt](https://github.com/suma419/aws-microservices/blob/883b94d9566ad608799482ae94bbda98cfc5217a/aws_microservices_gITHUB.png)

# 🚀 AWS Capstone Project – PHP Web App with MySQL on AWS

## 📌 Project Summary
This project designs and deploys a **highly available, scalable, cost-efficient, and secure cloud infrastructure** on AWS to host a PHP-based web application with a MySQL backend.  
It leverages **VPC, EC2 Auto Scaling, RDS Multi-AZ, ALB, NAT, and Secrets Manager** while following AWS best practices.

---

## 📌 Architecture

VPC (192.168.0.0/16)
│
├── 🌐 Public Subnets (2x) → Internet Gateway, NAT Gateway, Application Load Balancer
│
├── 🔒 Private App Subnets (2x) → Auto Scaling EC2 (PHP app servers)
│
└── 🗄️ Private DB Subnets (2x) → RDS MySQL (Multi-AZ, managed)
