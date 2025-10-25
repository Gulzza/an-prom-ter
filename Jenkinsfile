pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"   // ✅ your region
  }

  stages {

    stage('Checkout Code') {
      steps {
        echo "📦 Cloning repository..."
        git branch: 'main', url: 'https://github.com/Gulzza/an-prom-ter.git'
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        echo "🧱 Running Terraform..."
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds'   // ✅ Jenkins AWS credentials ID
          ]]) {
            sh '''
              terraform init -reconfigure
              terraform validate
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Generate Ansible Inventory') {
      steps {
        script {
          echo "📜 Generating dynamic inventory..."
          def instance_ip = sh(
            script: "cd terraform && terraform output -raw instance_public_ip",
            returnStdout: true
          ).trim()

          // Create inventory.ini dynamically for Ansible
          writeFile file: 'ansible/inventory.ini', text: """[webservers]
${instance_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${WORKSPACE}/.ssh/sensible.pem
"""
          echo "✅ Inventory created with IP: ${instance_ip}"
        }
      }
    }

    stage('Run Ansible Playbook') {
      steps {
        echo "🧩 Running Ansible Playbook..."
        dir('ansible') {
          withCredentials([sshUserPrivateKey(
            credentialsId: 'ssh-key',   // ✅ Jenkins SSH credentials ID
            keyFileVariable: 'SSH_KEY'
          )]) {
            sh '''
              ansible-playbook -i inventory.ini playbook.yml
            '''
          }
        }
      }
    }
  }

  post {
    success {
      script {
        echo "✅ Deployment completed successfully!"
        def ip = sh(script: "cd terraform && terraform output -raw instance_public_ip", returnStdout: true).trim()
        echo "🌐 Application (Prometheus) is accessible at: http://${ip}:9090"
      }
    }
    failure {
      echo "❌ Deployment failed. Please check the Jenkins console logs."
    }
  }
}
