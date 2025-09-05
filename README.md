
![Image Alt](https://github.com/suma419/aws-microservices/blob/429a7d4b4594c4b9f36f324791f15ecc12abcaea/aws_microservices_gITHUB.png)



# AWS Capstone – PHP Web App on AWS (End-to-End)

This bundle contains:
- `setup.sh` — Steps **1–6** (VPC, subnets, IGW, NAT, SGs, RDS create, ASG, ALB/TG).
- `post_setup_7_12.sh` — Steps **7–12** (routes, attach ASG to TG, deploy app, scaling, ALB URL).
- `index.php` — Simple PHP page that connects to MySQL and tracks visits.

## Usage

1) **Run Steps 1–6**
```bash
chmod +x setup.sh
./setup.sh
```

> Set/verify: `AMI_ID`, `KEY_PAIR`, `DB_PASSWORD` in `setup.sh` (and export `REGION` if not us-east-1).

2) **Run Steps 7–12**
```bash
chmod +x post_setup_7_12.sh
./post_setup_7_12.sh
```
This will:
- Create and associate **route tables**.
- Attach ASG to **Target Group** and set health checks.
- Wait for **RDS** and push `index.php` to instances via S3 + UserData.
- Create optional **scaling policy**.
- Print **ALB URL** to test: `http://<ALB_DNS>/index.php`.

## Notes
- Ensure your AWS CLI is configured and you have required permissions.
- For production, use **Secrets Manager/SSM** for DB creds and enable **HTTPS** with ACM + 443 listener.
- Clean up resources to avoid costs when finished.
