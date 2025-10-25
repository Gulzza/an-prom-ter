#!/bin/bash
# ===========================================================
# Automated Deployment Script (Terraform + Ansible)
# Author: Aisalkyn Aidarova
# ===========================================================

usage() {
  echo "Usage: $0 -e <environment> -a <app_name> [-c <count_instances>] [-t <instance_type>] [-u <user_name>]"
  exit 1
}

# ---------- Parse CLI Arguments ----------
while getopts "e:a:c:t:u:" opt; do
  case "$opt" in
    e) env_name=$OPTARG ;;
    a) app_name=$OPTARG ;;
    c) count_instance=$OPTARG ;;
    t) instance_type=$OPTARG ;;
    u) user_name=$OPTARG ;;
    *) usage ;;
  esac
done

# ---------- Validate Inputs ----------
if [ -z "$app_name" ] || [ -z "$env_name" ]; then
  echo "❌ Error: Missing required arguments (-e and -a)."
  usage
fi

# ---------- Display Summary ----------
echo "
==========================================
🚀 Deployment Details
------------------------------------------
Environment:      ${env_name}
Application Name: ${app_name}
Instance Count:   ${count_instance:-1}
Instance Type:    ${instance_type:-t2.micro}
User Name:        ${user_name:-ubuntu}
==========================================
"

# ---------- Set Environment Variables ----------
export TF_VAR_ENV_NAME=${env_name}
export TF_VAR_APP_NAME=${app_name}
export TF_VAR_NUM_SERVERS=${count_instance:-1}
export TF_VAR_SERVER_SIZE=${instance_type:-t2.micro}
export TF_VAR_USER_NAME=${user_name:-ubuntu}

# Make sure AWS CLI is configured before running this script
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "⚠️  AWS CLI not configured or credentials missing."
  echo "Run: aws configure"
  exit 1
fi

# ---------- Run Terraform ----------
echo "🧱 Running Terraform..."
cd terraform || { echo "❌ Terraform directory not found."; exit 1; }

terraform init -reconfigure
terraform validate
terraform apply -auto-approve

if [ $? -ne 0 ]; then
  echo "❌ Terraform apply failed!"
  exit 1
fi

# ---------- Capture Public IP ----------
instance_public_ip=$(terraform output -raw instance_public_ip)
echo "✅ Terraform deployment complete."
echo "🌐 EC2 Public IP: $instance_public_ip"

# ---------- Run Ansible ----------
echo "🧩 Running Ansible Playbook..."
cd ../ansible || { echo "❌ Ansible directory not found."; exit 1; }

# Create dynamic inventory file
cat > inventory.ini <<EOF
[webservers]
$instance_public_ip ansible_user=${user_name:-ubuntu} ansible_ssh_private_key_file=~/.ssh/sensible.pem
EOF

# Run playbook
ansible-playbook -i inventory.ini playbook.yml

if [ $? -eq 0 ]; then
  echo "🎉 Deployment successful!"
  echo "You can SSH into your instance with:"
  echo "ssh -i ~/.ssh/sensible.pem ${user_name:-ubuntu}@$instance_public_ip"
else
  echo "⚠️ Ansible playbook encountered errors. Check logs above."
fi

echo "✅ All done!"
