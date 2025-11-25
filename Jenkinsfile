sh '''
    set -e

    if [ ! -f ansible/terraform.json ]; then
        echo "terraform.json missing - infra not created"
        exit 1
    fi

    BASTION=$(jq -r '.bastion_public_ip.value' ansible/terraform.json)
    BUCKET=$(jq -r '.monitoring_bucket_name.value' ansible/terraform.json)
    REGION=$(jq -r '.aws_region.value' ansible/terraform.json)

    chmod 600 "$SSH_KEY_FILE"

    cd ansible

    export ANSIBLE_ROLES_PATH="$(pwd)/roles"
    export ANSIBLE_HOST_KEY_CHECKING=False

    # 🔥 Generate dynamic SSH config
    cat > ssh_proxy.cfg <<EOF
Host bastion
    HostName ${BASTION}
    User ubuntu
    IdentityFile ${SSH_KEY_FILE}
    StrictHostKeyChecking=no

Host 10.*
    ProxyJump bastion
    User ubuntu
    IdentityFile ${SSH_KEY_FILE}
    StrictHostKeyChecking=no
EOF

    # 🔥 Tell ansible to use SSH proxy config
    export ANSIBLE_SSH_ARGS="-F $(pwd)/ssh_proxy.cfg"

    # 🔥 DO NOT PASS --private-key, let SSH config handle it
    
    ansible-playbook \
      -i inventory_aws_ec2.yml \
      playbooks/install_tools.yml \
      --extra-vars "bastion_public_ip=$BASTION monitoring_bucket=$BUCKET aws_region=$REGION"
'''
