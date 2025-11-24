pipeline {
    agent any

     environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-creds').AccessKey
        AWS_SECRET_ACCESS_KEY = credentials('aws-creds').Secret
        AWS_DEFAULT_REGION    = "ap-south-1"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup AWS Credentials') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds', region: 'ap-south-1')]) {
                    sh '''
                        mkdir -p ~/.aws
                        cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh '''
                    terraform fmt -recursive
                    terraform validate
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Approval') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: "Approve Terraform Apply?"
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Export Terraform Outputs') {
            steps {
                dir('terraform') {
                    sh 'terraform output -json > ../ansible/terraform.json'
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                sshagent(credentials: ['prometheus-key']) {
                    sh '''
                        cd ansible
                        ansible-playbook playbooks/install_tools.yml
                        ansible-playbook playbooks/configure_bastion.yml
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "🎉 Deployment Successful!"
        }
        failure {
            echo "❌ Deployment Failed"
        }
    }
}
