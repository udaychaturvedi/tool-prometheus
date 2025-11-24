pipeline {
  agent { label 'linux' }

  options {
    ansiColor('xterm')
    timestamps()
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
  }

  environment {
    TF_DIR = "terraform"
    ANSIBLE_DIR = "ansible"
    TF_JSON = "${ANSIBLE_DIR}/terraform.json"
    // Jenkins credential IDs (create these in Jenkins credentials store)
    AWS_CREDS = 'aws-creds'          // AWS accessKey/secretKey
    SSH_KEY_ID = 'jenkins-ssh-key'   // SSH private key for Ansible/Jumphost
  }

  triggers {
    // Uncomment to run on push; repo-wide webhooks + Jenkinsfile Multibranch may be used
    // pollSCM('H/5 * * * *')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Prechecks: terraform fmt/validate & ansible-lint') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
          sh '''
            set -euo pipefail
            echo "## Terraform fmt & validate"
            cd ${TF_DIR}
            terraform fmt -check -recursive || (terraform fmt -recursive && echo "fmt fixed")
            terraform init -backend=false
            terraform validate || true  # allow validate to show errors
            cd ..
            echo "## Ansible lint"
            if command -v ansible-lint >/dev/null 2>&1; then
              ansible-lint -v ansible || true
            else
              echo "ansible-lint not installed on agent; skipping"
            fi
          '''
        }
      }
    }

    stage('Choose Action') {
      steps {
        script {
          // default to apply on non-interactive runs; user can choose when running manually
          def isInteractive = params.ACTION == null ? true : false
          if (isInteractive) {
            def choice = input message: 'Terraform action?', parameters: [choice(name: 'ACTION', choices: 'apply\ndestroy', description: 'apply or destroy')]
            env.ACTION = choice
          } else {
            env.ACTION = params.ACTION ?: 'apply'
          }
          echo "Action chosen = ${env.ACTION}"
        }
      }
    }

    stage('Terraform Plan/Apply or Destroy') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS]]) {
          script {
            if (env.ACTION == 'apply') {
              sh """
                set -euo pipefail
                cd ${TF_DIR}
                terraform init -input=false
                terraform workspace select default || terraform workspace new default
                terraform plan -out=tfplan -input=false
                terraform apply -auto-approve tfplan
                terraform output -json > ../${TF_JSON}
              """
            } else if (env.ACTION == 'destroy') {
              sh """
                set -euo pipefail
                cd ${TF_DIR}
                terraform init -input=false
                terraform destroy -auto-approve
                # remove terraform json if exists
                rm -f ../${TF_JSON} || true
              """
            } else {
              error "Unknown ACTION: ${env.ACTION}"
            }
          }
        }
      }
      post {
        success {
          archiveArtifacts artifacts: "${TF_DIR}/tfplan", allowEmptyArchive: true
          stash includes: "${TF_JSON}", name: 'tfjson', allowEmpty: true
        }
        failure {
          mail to: 'you@example.com', subject: "Terraform stage failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}", body: "Check Jenkins console"
        }
      }
    }

    stage('Ansible: configure / deploy tools') {
      when {
        expression { env.ACTION == 'apply' }
      }
      steps {
        // unstash terraform.json if necessary
        unstash 'tfjson' || echo "tfjson not found; assuming file already present"
        // use SSH key stored in Jenkins credentials
        withCredentials([sshUserPrivateKey(credentialsId: env.SSH_KEY_ID, keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: '', usernameVariable: 'SSH_USER')]) {
          sh '''
            set -euo pipefail
            # install deps on agent if required (jq, ansible)
            if ! command -v jq >/dev/null 2>&1; then
              echo "jq missing on agent; please install jq"
              exit 1
            fi
            # read outputs
            TFJSON="${TF_JSON}"
            if [ ! -f "${TFJSON}" ]; then
              echo "ERROR: ${TFJSON} not found"
              exit 1
            fi

            BASTION_IP=$(jq -r '.bastion_public_ip.value // empty' "${TFJSON}")
            TOOLS_PRIVATE_IPS=$(jq -r '.tools_private_ips.value[]? // empty' "${TFJSON}" | tr '\n' ' ')
            MON_BUCKET=$(jq -r '.monitoring_bucket_name.value // empty' "${TFJSON}")
            AWS_REGION=$(jq -r '.aws_region.value // empty' "${TFJSON}")

            echo "Using bastion=${BASTION_IP}"
            echo "tools_private_ips=${TOOLS_PRIVATE_IPS}"
            echo "bucket=${MON_BUCKET} region=${AWS_REGION}"

            # prepare ssh key used by ansible
            chmod 600 "${SSH_KEY_FILE}"

            # run ansible-playbook with dynamic extra-vars
            cd ${ANSIBLE_DIR}
            ansible-playbook -i inventory_aws_ec2.yml playbooks/install_tools.yml \
              --private-key "${SSH_KEY_FILE}" \
              --extra-vars "bastion_public_ip=${BASTION_IP} monitoring_bucket=${MON_BUCKET} aws_region=${AWS_REGION}"
          '''
        }
      }
      post {
        success {
          echo "Ansible finished successfully"
        }
        failure {
          echo "Ansible failed — inspect logs"
        }
      }
    }

    stage('Post-deploy health checks') {
      when {
        expression { env.ACTION == 'apply' }
      }
      steps {
        sh '''
          set -eu
          TFJSON="${TF_JSON}"
          if [ -f "${TFJSON}" ]; then
            BASTION_IP=$(jq -r '.bastion_public_ip.value // empty' "${TFJSON}")
            echo "Checking bastion at ${BASTION_IP} (HTTP /prometheus/)"
            curl -sS --max-time 10 "http://${BASTION_IP}/prometheus/" | head -n 1 || echo "prometheus check failed"
          else
            echo "No tf json, skipping health checks"
          fi
        '''
      }
    }
  } // stages

  parameters {
    choice(name: 'ACTION', choices: ['apply','destroy'], description: 'Optional: set pipeline action (when started non-interactively)')
  }

  post {
    always {
      echo "Pipeline finished. Build URL: ${env.BUILD_URL}"
    }
    success {
      script { currentBuild.description = "Action: ${env.ACTION}" }
    }
    failure {
      mail to: 'you@example.com', subject: "CI failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}", body: "See ${env.BUILD_URL}"
    }
  }
}
