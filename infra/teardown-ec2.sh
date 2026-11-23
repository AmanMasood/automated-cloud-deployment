#!/usr/bin/env bash
# Remove the demo instance and security group created by launch-ec2.sh.
set -euo pipefail
AWS_REGION="${AWS_REGION:-eu-central-1}"
NAME_TAG="${NAME_TAG:-cloud-deploy-demo}"

IDS=$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${NAME_TAG}" "Name=instance-state-name,Values=pending,running,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [[ -n "$IDS" ]]; then
  # shellcheck disable=SC2086 # IDS is a space-separated list on purpose
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $IDS >/dev/null
  # shellcheck disable=SC2086
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $IDS
  echo "Terminated: $IDS"
fi
SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=${NAME_TAG}-sg" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)
if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
  aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG_ID"
  echo "Deleted security group $SG_ID"
fi
