#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env file if it exists
if [[ -f .env ]]; then
  source .env
fi

### ====== CONFIG ======
AWS_REGION="${AWS_REGION:-us-east-1}"

S3_BUCKET="${S3_BUCKET:-your-bucket-name}"
S3_KEY="${S3_KEY:-azure/your-disk.vhd}"

VM_DESCRIPTION="${VM_DESCRIPTION:-Your VM Description}"
PROJECT_TAG="${PROJECT_TAG:-your-project}"
LICENSE_TYPE="${LICENSE_TYPE:-AWS}"
### ====================

# Validate required variables
if [[ "$S3_BUCKET" == "your-bucket-name" ]]; then
  echo "[!] Please configure S3_BUCKET in .env file"
  exit 1
fi

echo "[*] Using region: $AWS_REGION"
export AWS_REGION

### 1. Create / update vmimport role (trust policy)

cat > trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "vmie.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

if aws iam get-role --role-name vmimport >/dev/null 2>&1; then
  echo "[*] vmimport role exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name vmimport \
    --policy-document file://trust-policy.json
else
  echo "[*] Creating vmimport role..."
  aws iam create-role \
    --role-name vmimport \
    --assume-role-policy-document file://trust-policy.json
fi

### 2. Attach inline vmimport policy (S3 + EC2 permissions)

cat > vmimport-role-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$S3_BUCKET",
        "arn:aws:s3:::$S3_BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ModifySnapshotAttribute",
        "ec2:CopySnapshot",
        "ec2:RegisterImage",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

echo "[*] Attaching vmimport inline policy..."
aws iam put-role-policy \
  --role-name vmimport \
  --policy-name vmimport \
  --policy-document file://vmimport-role-policy.json

### 3. Generate presigned URL

echo "[*] Generating presigned URL for s3://$S3_BUCKET/$S3_KEY ..."
PRESIGNED_URL=$(aws s3 presign "s3://$S3_BUCKET/$S3_KEY" --expires-in 86400)

echo "[*] PRESIGNED_URL generated."

### 4. Build import-image.json

cat > import-image.json <<EOF
{
  "Description": "$VM_DESCRIPTION",
  "LicenseType": "$LICENSE_TYPE",
  "TagSpecifications": [
    {
      "ResourceType": "import-image-task",
      "Tags": [
        { "Key": "Project", "Value": "$PROJECT_TAG" }
      ]
    }
  ],
  "DiskContainers": [
    {
      "Description": "$VM_DESCRIPTION",
      "Format": "VHD",
      "Url": "$PRESIGNED_URL"
    }
  ]
}
EOF

echo "[*] import-image.json created."

### 5. Call import-image

echo "[*] Starting EC2 import-image..."
IMPORT_OUTPUT=$(aws ec2 import-image --cli-input-json file://import-image.json)
echo "$IMPORT_OUTPUT"

IMPORT_TASK_ID=$(echo "$IMPORT_OUTPUT" | jq -r '.ImportTaskId' 2>/dev/null || true)

if [[ -n "${IMPORT_TASK_ID:-}" && "$IMPORT_TASK_ID" != "null" ]]; then
  echo "[*] Import task started: $IMPORT_TASK_ID"
  echo "    To monitor:"
  echo "    aws ec2 describe-import-image-tasks --import-task-ids $IMPORT_TASK_ID"
else
  echo "[!] Could not parse ImportTaskId from output above. Please check the response."
fi

