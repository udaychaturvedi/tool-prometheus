node {

    // ---------------------------
    // GLOBAL ENV VARS
    // ---------------------------
    env.TF_DIR = "terraform"
    env.ANSIBLE_DIR = "ansible"
    env.TF_JSON = "ansible/terraform.json"
    env.AWS_CREDS = "aws-creds"
    env.SSH_KEY_ID = "ubuntu"   // your actual Jenkins credential ID

    timestamps {

        stage("Checkout") {
            checkout scm
        }

        // ---------------------------
        // VALIDATE TERRAFORM
        // ---------------------------
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

        // ---------------------------
        // USER CHOICE AFTER VALIDATE
        // ---------------------------
        stage("Choose Action") {
            ACTION = input(
                message: "Terraform: Choose action",
                parameters: [choice(name: 'ACTION', choices: ['apply','destroy'])]
            )
            echo "User selected action = ${ACTION}"
        }

        // ---------------------------
        // TERRAFORM APPLY OR DESTROY
        // ---------------------------
        stage("Terraform Apply/Destroy") {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
                if (ACTION == "apply") {

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

        // ---------------------------
        // RUN ANSIBLE (ONLY IF APPLY)
        // ---------------------------
        if (ACTION == "apply") {

            stage("Run Ansible") {
                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_KEY_ID,
                    keyFileVariable: 'SSH_KEY_FILE',
                    usernameVariable: 'SSH_USER'
                )]) {

                    sh """
                        set -e

                        # Load Terraform outputs
                        BASTION=\$(jq -r '.bastion_public_ip.value' ${TF_JSON})
                        BUCKET=\$(jq -r '.monitoring_bucket_name.value' ${TF_JSON})
                        REGION=\$(jq -r '.aws_region.value' ${TF_JSON})

                        chmod 600 "$SSH_KEY_FILE"

                        cd ${ANSIBLE_DIR}

                        export ANSIBLE_ROLES_PATH="\$(pwd)/roles"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        # ---------------------------------------------------
                        # Generate SSH Proxy Config (safe placeholders)
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

                        # Replace placeholders with actual values
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

            // ---------------------------
            // HEALTH CHECK
            // ---------------------------
            stage("Health Check") {
                sh """
                    BASTION=\$(jq -r '.bastion_public_ip.value' ${TF_JSON})
                    echo "Checking Prometheus..."
                    curl -I --max-time 10 http://\$BASTION/prometheus/ || true
                """
            }
        }

        echo "Pipeline Completed: ${env.BUILD_URL}"
    }
}
