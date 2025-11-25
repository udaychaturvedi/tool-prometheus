node {

    // ------------ configuration --------------
    env.TF_DIR      = "terraform"
    env.ANSIBLE_DIR = "ansible"
    env.TF_JSON     = "ansible/terraform.json"

    // credential IDs you have in Jenkins
    env.AWS_CREDS   = "aws-creds"
    env.SSH_KEY_ID  = "ubuntu"

    timestamps {

        stage("Checkout") {
            checkout scm
        }

        stage("Terraform Validate") {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
                sh """
                    set -e
                    cd ${TF_DIR}
                    terraform fmt -recursive || true
                    terraform init -backend=false
                    terraform validate || true
                """
            }
        }

        stage("Choose Action") {
            // ask the user after validate
            ACTION = input(
                message: "Terraform: choose action",
                parameters: [choice(name: 'ACTION', choices: ['apply','destroy'], description: 'apply or destroy')]
            )
            echo "User selected: ${ACTION}"
        }

        stage("Terraform Apply/Destroy") {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
                if (ACTION == 'apply') {
                    sh """
                        set -e
                        cd ${TF_DIR}
                        terraform init
                        terraform plan -out=tfplan
                        terraform apply -auto-approve tfplan
                        terraform output -json > ../${TF_JSON}
                    """
                } else {
                    sh """
                        set -e
                        cd ${TF_DIR}
                        terraform init
                        terraform destroy -auto-approve
                    """
                }
            }
        }

        // Run Ansible only after apply
        if (ACTION == 'apply') {

            stage("Run Ansible") {
                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_KEY_ID,
                    keyFileVariable: 'SSH_KEY_FILE',
                    usernameVariable: 'SSH_USER'
                )]) {

                    // The entire work is inside a single shell script.
                    // Important: all $ signs used in the shell are escaped (e.g. \$BASTION) so Groovy doesn't interpolate secrets.
                    sh """
                        set -e

                        # ensure terraform outputs exist
                        if [ ! -f ${TF_JSON} ]; then
                            echo "ERROR: ${TF_JSON} not found. Terraform may have failed."
                            exit 1
                        fi

                        # read outputs (shell variables)
                        BASTION=\$(jq -r '.bastion_public_ip.value' ${TF_JSON})
                        BUCKET=\$(jq -r '.monitoring_bucket_name.value' ${TF_JSON} 2>/dev/null || echo "null")
                        REGION=\$(jq -r '.aws_region.value' ${TF_JSON} 2>/dev/null || echo "null")

                        echo "Using bastion=\$BASTION bucket=\$BUCKET region=\$REGION"

                        # ensure the SSH key file has secure perms
                        chmod 600 "\$SSH_KEY_FILE"

                        cd ${ANSIBLE_DIR}

                        export ANSIBLE_ROLES_PATH="\$(pwd)/roles"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        # -------------------------
                        # Generate SSH proxy config safely using placeholders
                        # -------------------------
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

                        # Replace placeholders with actual runtime values (safe - executed in shell)
                        sed -i "s/BASTION_PLACEHOLDER/\$BASTION/" ssh_proxy.cfg
                        # use # as sep to allow slashes in path
                        sed -i "s#SSHKEY_PLACEHOLDER#\$SSH_KEY_FILE#" ssh_proxy.cfg

                        export ANSIBLE_SSH_ARGS="-F \$(pwd)/ssh_proxy.cfg"

                        echo "Using ANSIBLE_SSH_ARGS=\$ANSIBLE_SSH_ARGS"
                        echo "SSH config:"
                        sed -n '1,160p' ssh_proxy.cfg || true

                        # -------------------------
                        # Run the Ansible playbook (do not pass --private-key; ssh config controls it)
                        # -------------------------
                        ansible-playbook \\
                          -i inventory_aws_ec2.yml \\
                          playbooks/install_tools.yml \\
                          --extra-vars "bastion_public_ip=\$BASTION monitoring_bucket=\$BUCKET aws_region=\$REGION"
                    """
                }
            }

            stage("Health Check") {
                sh """
                    set -e
                    BASTION=\$(jq -r '.bastion_public_ip.value' ${TF_JSON})
                    echo "Checking Prometheus endpoint on \$BASTION..."
                    curl -I --max-time 10 http://\$BASTION/prometheus/ || echo "Prometheus check failed (may still be starting)."
                """
            }
        }

        stage("Finish") {
            echo "Pipeline finished. Build URL: ${env.BUILD_URL}"
        }
    }
}
