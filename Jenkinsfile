pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        cd terraform
                        terraform init
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        cd terraform
                        terraform validate
                    '''
                }
            }
        }

        stage('Choose Action') {
            steps {
                script {
                    ACTION = input message: 'Terraform Action?', parameters: [
                        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Choose what to do:')
                    ]
                }
            }
        }

        stage('Terraform Apply/Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        cd terraform
                        if [ "$ACTION" = "apply" ]; then
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                        elif [ "$ACTION" = "destroy" ]; then
                            terraform destroy -auto-approve
                        fi
                    '''
                }
            }
        }
    }
}
