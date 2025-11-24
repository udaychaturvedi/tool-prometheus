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
                    def userChoice = input(
                        id: 'actionInput',
                        message: 'Terraform Action?',
                        parameters: [
                            choice(
                                name: 'ACTION',
                                choices: ['apply', 'destroy'],
                                description: 'Choose what to execute'
                            )
                        ]
                    )
                    echo "You selected: ${userChoice}"
                    env.ACTION = userChoice   // Set for next stages
                }
            }
        }

        stage('Terraform Apply/Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {

                    sh '''
                        cd terraform
                        echo "ACTION selected = $ACTION"

                        if [ "$ACTION" = "apply" ]; then
                            echo "Running Terraform PLAN + APPLY"
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                        elif [ "$ACTION" = "destroy" ]; then
                            echo "Running Terraform DESTROY"
                            terraform destroy -auto-approve
                        else
                            echo "ERROR: Unknown ACTION -> $ACTION"
                            exit 1
                        fi
                    '''
                }
            }
        }
    }
}
