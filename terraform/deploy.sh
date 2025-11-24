#!/bin/bash

echo "Fetching your current public IPv4..."
MY_IP=$(curl -4 -s ifconfig.me)/32
echo "Your IPv4 is: $MY_IP"

echo "Updating my_ip in variables.tf..."
sed -i "s|my_ip\".*|my_ip\" {\n  default = \"$MY_IP\"\n}|" variables.tf

echo "Initializing Terraform..."
terraform init -upgrade

echo "Applying Terraform..."
terraform apply -auto-approve

echo "Done!"

