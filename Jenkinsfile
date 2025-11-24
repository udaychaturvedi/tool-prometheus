pipeline {
    agent any

    environment {
        TF_DIR = "terraform"
        ANSIBLE_DIR = "ansible"
        TF_JSON = "ansible/terraform.json"

        AWS_CREDS = "aws-creds"
        SSH_KEY_ID = "jenkins-ssh-key"
    }

    options {
        timestamps()
        buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
    }

    parameters {
        choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Apply or Destroy infra')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prechecks') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDS]]) {
                    sh '''
                        set -e
                        echo "===== Terraform Prechecks ====="
                        cd terraform
                        terraform fmt -recursive || true
                        terraform init -backend=false
                        terraform validate || true
                    '''
                }
            }
        }

        stage('Terraform Apply/Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDS]]) {
                    script {

                        if (params.ACTION == "apply") {
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
            post {
                success {
                    archiveArtifacts artifacts: "terraform/tfplan", onlyIfSuccessful: true
                }
            }
        }

        stage('Run Ansible') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: SSH_KEY_ID, keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {

                    sh '''
                        set -e

                        echo "===== Loading Terraform Outputs ====="
                        if [ ! -f ansible/terraform.json ]; then
                            echo "ERROR: terraform.json missing"
                            exit 1
                        fi

                        BASTION=$(jq -r '.bastion_public_ip.value' ansible/terraform.json)
                        BUCKET=$(jq -r '.monitoring_bucket_name.value' ansible/terraform.json)
                        REGION=$(jq -r '.aws_region.value' ansible/terraform.json)

                        chmod 600 "$SSH_KEY_FILE"

                        echo "Running Ansible..."
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
            when { expression { params.ACTION == 'apply'} }
            steps {
                sh '''
                    set -e
                    BASTION=$(jq -r '.bastion_public_ip.value' ansible/terraform.json)
                    
                    echo "Checking Prometheus: http://$BASTION/prometheus/"
                    curl -I --max-time 10 http://$BASTION/prometheus/ || echo "Prometheus may not be ready yet"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. URL: ${env.BUILD_URL}"
        }
    }
}
