#!/usr/bin/env bash
set -euo pipefail

TF_DIR="./terraform"
ANSIBLE_DIR="./ansible"

echo "=== Running Terraform ==="
pushd "$TF_DIR" >/dev/null
terraform apply -auto-approve
terraform output -json > "../$ANSIBLE_DIR/terraform.json"
popd >/dev/null

echo "=== Reading Terraform Outputs ==="
BASTION_IP=$(jq -r '.bastion_public_ip.value' "$ANSIBLE_DIR/terraform.json")
echo "Bastion Public IP = $BASTION_IP"

echo "=== Running Ansible Playbooks ==="
cd "$ANSIBLE_DIR"

ansible-playbook -i inventory_aws_ec2.yml playbooks/install_tools.yml --extra-vars "bastion_public_ip=${BASTION_IP}"

ansible-playbook -i inventory_aws_ec2.yml playbooks/install_tools.yml \
  --extra-vars "bastion_public_ip=${BASTION_IP} monitoring_bucket=$(jq -r '.monitoring_bucket_name.value' ansible/terraform.json) aws_region=$(jq -r '.monitoring_kms_arn.value' ansible/terraform.json)" 

S3_BUCKET=$(terraform output -raw monitoring_bucket_name)

ANSIBLE_EXTRA="-e s3_bucket=$S3_BUCKET"

cd ..
echo "=== Deployment Completed ==="
