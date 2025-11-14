# Import Azure VHD to AWS AMI  
Using Presigned S3 URL + vmimport IAM Role

This project automates the process of importing an Azure-exported **VHD** into AWS as an AMI.  
All required configuration files (IAM trust policy, IAM inline policy, Terraform module, CloudFormation template, and JSON import payload) are already included in this repository.

## 📂 Repository Structure

```
.
├── .env.sample
├── .gitignore
├── trust-policy.json
├── vmimport-role-policy.json
├── import-image.json
├── import-vhd-to-ami.sh
├── launch-ec2.sh
├── vmimport.tf
├── vmimport-role.yaml
└── README.md
```

## 1. Requirements

✔ VHD file (local or public URL)  
✔ AWS CLI v2  
✔ IAM permissions

## 2. Setup Environment

Copy the sample environment file and configure your settings:

```bash
cp .env.sample .env
```

Edit `.env` with your values:

```bash
AWS_REGION=us-east-1
S3_BUCKET=your-bucket-name
S3_KEY=azure/your-disk.vhd
VM_DESCRIPTION=Your VM Description
PROJECT_TAG=your-project
LICENSE_TYPE=AWS

# VPC Configuration (optional)
VPC_ID=vpc-12345678
SUBNET_ID=subnet-12345678
SECURITY_GROUP_ID=sg-12345678
```

## 3. Stream VHD to S3 (Optional)

### From Public URL

```
curl -L "https://example.com/disk.vhd" | aws s3 cp - s3://your-bucket/azure/disk.vhd
```

### From Local File

```
aws s3 cp disk.vhd s3://your-bucket/azure/disk.vhd
```

## 4. Configure IAM Role (vmimport)

### CLI

```
aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
aws iam update-assume-role-policy --role-name vmimport --policy-document file://trust-policy.json
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://vmimport-role-policy.json
```

### Terraform

```bash
terraform init
terraform apply -var="s3_bucket_name=$S3_BUCKET"
```

### CloudFormation

```bash
aws cloudformation deploy --template-file vmimport-role.yaml --stack-name vmimport-role --capabilities CAPABILITY_NAMED_IAM --parameter-overrides S3BucketName=$S3_BUCKET
```

## 5. Generate Presigned URL

```bash
PRESIGNED_URL=$(aws s3 presign s3://$S3_BUCKET/$S3_KEY --expires-in 86400)
```

## 6. Update import-image.json

```
sed -i "s|PRESIGNED_URL_HERE|$PRESIGNED_URL|g" import-image.json
```

## 7. Run Import Task

```
aws ec2 import-image --cli-input-json file://import-image.json
```

## 8. Monitor Progress

```
aws ec2 describe-import-image-tasks --import-task-ids import-ami-xxxx
```

## 9. Automation Script

```bash
./import-vhd-to-ami.sh
```

## 10. Launch EC2 from AMI (Optional)

After import completes, launch EC2 instance:

```bash
./launch-ec2.sh ami-1234567890abcdef0
```

## 11. Workflow Diagram

(mermaid-compatible)

## 12. Troubleshooting

- vmimport role missing permissions  
- URL expired  
- Unsupported format  

