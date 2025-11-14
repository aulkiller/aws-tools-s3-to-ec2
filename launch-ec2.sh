#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env file if it exists
if [[ -f .env ]]; then
  source .env
fi

### ====== CONFIG ======
AWS_REGION="${AWS_REGION:-us-east-1}"
VPC_ID="${VPC_ID:-}"
SUBNET_ID="${SUBNET_ID:-}"
SECURITY_GROUP_ID="${SECURITY_GROUP_ID:-}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
KEY_NAME="${KEY_NAME:-}"
### ====================

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <AMI_ID>"
  echo "Example: $0 ami-1234567890abcdef0"
  exit 1
fi

AMI_ID="$1"

echo "[*] Using region: $AWS_REGION"
export AWS_REGION

# Build launch parameters
LAUNCH_PARAMS="--image-id $AMI_ID --instance-type $INSTANCE_TYPE"

if [[ -n "$SUBNET_ID" ]]; then
  LAUNCH_PARAMS="$LAUNCH_PARAMS --subnet-id $SUBNET_ID"
fi

if [[ -n "$SECURITY_GROUP_ID" ]]; then
  LAUNCH_PARAMS="$LAUNCH_PARAMS --security-group-ids $SECURITY_GROUP_ID"
fi

if [[ -n "$KEY_NAME" ]]; then
  LAUNCH_PARAMS="$LAUNCH_PARAMS --key-name $KEY_NAME"
fi

echo "[*] Launching EC2 instance from AMI: $AMI_ID"
echo "[*] Launch parameters: $LAUNCH_PARAMS"

INSTANCE_OUTPUT=$(aws ec2 run-instances $LAUNCH_PARAMS)
INSTANCE_ID=$(echo "$INSTANCE_OUTPUT" | jq -r '.Instances[0].InstanceId')

echo "[*] Instance launched: $INSTANCE_ID"
echo "    To monitor:"
echo "    aws ec2 describe-instances --instance-ids $INSTANCE_ID"