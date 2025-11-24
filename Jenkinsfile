pipeline {
    agent any

    environment {
    TF_DIR = "terraform"
    ANSIBLE_DIR = "ansible"
    TF_JSON = "ansible/terraform.json"

    AWS_CREDS = "aws-creds"
    SSH_KEY_ID = "jenkins"   // <<< FIXED
}


    options {
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Terraform Validate') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDS]]) {
                    sh '''
                        set -e
                        cd terraform
                        terraform fmt -recursive || true
                        terraform init -backend=false
                        terraform validate || true
                    '''
                }
            }
        }

        stage('Choose Action') {
            steps {
                script {
                    env.ACTION = input(
                        id: 'action_input',
                        message: 'Terraform: Choose what to do',
                        parameters: [
                            choice(name: 'ACTION', choices: ['apply','destroy'])
                        ]
                    )
                    echo "Action selected = ${env.ACTION}"
                }
            }
        }

        stage('Terraform Apply/Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDS]]) {

                    script {
                        if (env.ACTION == "apply") {
                            sh """
                                set -e
                                cd terraform
                                terraform init
                                terraform plan -out=tfplan
                                terraform apply -auto-approve tfplan
                                terraform output -json > ../${TF_JSON}
                            """
                        } else {
                            sh """
                                set -e
                                cd terraform
                                terraform init
                                terraform destroy -auto-approve
                            """
                        }
                    }
                }
            }
        }

        stage('Run Ansible') {
            when { expression { env.ACTION == 'apply' } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: SSH_KEY_ID, keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        set -e
                        if [ ! -f ansible/terraform.json ]; then
                          echo "terraform.json missing — infra not created"
                          exit 1
                        fi

                        BASTION=$(jq -r '.bastion_public_ip.value' ansible/terraform.json)
                        BUCKET=$(jq -r '.monitoring_bucket_name.value' ansible/terraform.json)
                        REGION=$(jq -r '.aws_region.value' ansible/terraform.json)

                        chmod 600 "$SSH_KEY_FILE"

                        cd ansible
                        ansible-playbook \
                          -i inventory_aws_ec2.yml \
                          playbooks/install_tools.yml \
                          --private-key "$SSH_KEY_FILE" \
                          --extra-vars "bastion_public_ip=$BASTION monitoring_bucket=$BUCKET aws_region=$REGION"
                    '''
                }
            }
        }

        stage('Health Check') {
            when { expression { env.ACTION == 'apply' } }

            steps {
                sh '''
                    set -e
                    BASTION=$(jq -r '.bastion_public_ip.value' ansible/terraform.json)

                    echo "Checking Prometheus endpoint..."
                    curl -I --max-time 10 http://$BASTION/prometheus/ || true
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
            echo "URL: ${env.BUILD_URL}"
        }
    }
}
