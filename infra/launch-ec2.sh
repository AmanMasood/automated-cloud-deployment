#!/usr/bin/env bash
# Provision a single EC2 instance with the AWS CLI.
# Safe by default: prints the plan and does nothing unless CONFIRM=yes is set.
#
#   AWS_REGION=eu-central-1 KEY_NAME=my-key DEPLOY_PUBLIC_KEY="ssh-ed25519 AAA..." ./infra/launch-ec2.sh
#   CONFIRM=yes ... ./infra/launch-ec2.sh
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-central-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"      # free-tier eligible in most regions
KEY_NAME="${KEY_NAME:?set KEY_NAME to an existing EC2 key pair}"
DEPLOY_PUBLIC_KEY="${DEPLOY_PUBLIC_KEY:?set DEPLOY_PUBLIC_KEY to the CI deploy public key}"
NAME_TAG="${NAME_TAG:-cloud-deploy-demo}"
SSH_CIDR="${SSH_CIDR:-0.0.0.0/0}"              # restrict to your IP in real use
CONFIRM="${CONFIRM:-no}"

AMI_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"

echo "Plan:"
echo "  region        ${AWS_REGION}"
echo "  instance type ${INSTANCE_TYPE}"
echo "  key pair      ${KEY_NAME}"
echo "  SSH allowed   ${SSH_CIDR}"
echo "  ports         22, 80, 443"

if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Dry run only. Re-run with CONFIRM=yes to create resources (this may incur AWS charges)."
  exit 0
fi

AMI_ID=$(aws ssm get-parameter --region "$AWS_REGION" --name "$AMI_PARAM" --query Parameter.Value --output text)
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)

SG_ID=$(aws ec2 create-security-group --region "$AWS_REGION" --vpc-id "$VPC_ID" \
  --group-name "${NAME_TAG}-sg" --description "web + ssh for ${NAME_TAG}" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$SSH_CIDR"
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0

USER_DATA=$(mktemp)
sed "s|\${DEPLOY_PUBLIC_KEY}|${DEPLOY_PUBLIC_KEY}|" "$(dirname "$0")/cloud-init.yaml" > "$USER_DATA"

INSTANCE_ID=$(aws ec2 run-instances --region "$AWS_REGION" --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SG_ID" \
  --user-data "file://${USER_DATA}" \
  --metadata-options HttpTokens=required \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME_TAG}}]" \
  --query 'Instances[0].InstanceId' --output text)

echo "Waiting for ${INSTANCE_ID}..."
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance ${INSTANCE_ID} running at ${PUBLIC_IP}"
echo "Next: point your domain's A record at ${PUBLIC_IP}, then run scripts/setup-nginx-ssl.sh on the server."
