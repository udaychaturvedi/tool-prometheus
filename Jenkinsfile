stage("Run Ansible") {
    if (ACTION == "apply") {

        withCredentials([sshUserPrivateKey(
            credentialsId: env.SSH_KEY_ID,
            keyFileVariable: 'SSH_KEY_FILE',
            usernameVariable: 'SSH_USER'
        )]) {

            sh """
                set -e

                # Read Terraform outputs (shell variables)
                BASTION=\$(jq -r '.bastion_public_ip.value' ${TF_JSON})
                BUCKET=\$(jq -r '.monitoring_bucket_name.value' ${TF_JSON})
                REGION=\$(jq -r '.aws_region.value' ${TF_JSON})

                chmod 600 "$SSH_KEY_FILE"

                cd ${ANSIBLE_DIR}

                export ANSIBLE_ROLES_PATH="\$(pwd)/roles"
                export ANSIBLE_HOST_KEY_CHECKING=False

                # ---------------------------------------------------
                # Generate SSH Proxy Config (NO GROOVY EXPANSION!)
                # ---------------------------------------------------
cat > ssh_proxy.cfg << 'EOF'
Host bastion
    HostName BASTION_PLACEHOLDER
    User ubuntu
    IdentityFile SSHKEY_PLACEHOLDER
    StrictHostKeyChecking=no

Host 10.*
    ProxyJump bastion
    User ubuntu
    IdentityFile SSHKEY_PLACEHOLDER
    StrictHostKeyChecking=no
EOF

                # Replace placeholders safely in shell
                sed -i "s/BASTION_PLACEHOLDER/\$BASTION/" ssh_proxy.cfg
                sed -i "s#SSHKEY_PLACEHOLDER#$SSH_KEY_FILE#" ssh_proxy.cfg

                export ANSIBLE_SSH_ARGS="-F \$(pwd)/ssh_proxy.cfg"

                # ---------------------------------------------------
                # Run Ansible
                # ---------------------------------------------------
                ansible-playbook \\
                  -i inventory_aws_ec2.yml \\
                  playbooks/install_tools.yml \\
                  --extra-vars "bastion_public_ip=\$BASTION monitoring_bucket=\$BUCKET aws_region=\$REGION"
            """
        }
    }
}
