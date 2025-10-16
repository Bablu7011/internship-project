Assignment 1:- DevOps Assignment – Automate EC2 Deployment

This project demonstrates how to automate the provisioning of an EC2 instance on AWS using Terraform.

🚀 Steps to Deploy
1. Configure AWS CLI

Run the following command and provide your AWS Access Key, Secret Key, Region, and Output format:

aws configure

2. Create an SSH Key

Generate an SSH key locally:

ssh-keygen -t rsa -b 2048 -f ~/.ssh/mykey


Import the public key into AWS:

aws ec2 import-key-pair \
  --key-name "mykey" \
  --public-key-material fileb://~/.ssh/my-key.pub

3. Set Environment Variable for Key Name

Avoid hardcoding the key in Terraform. Instead, export it as an environment variable:

export TF_VAR_key_name="aws-key"

4. Deploy Infrastructure with Terraform

Go to the Terraform directory and run:

cd terraform
terraform init
terraform apply -auto-approve

5. Get Public IP of EC2

After deployment, fetch the public IP:

terraform output ec2_public_ip

6. Test in Browser

Open your browser and visit:

http://<PUBLIC_IP>

7. Destroy Resources After Testing

To avoid unnecessary costs, destroy the infrastructure when no longer needed:

terraform destroy -auto-approve




📌 Assignment 2 – S3 Integration, IAM, and Logging

This assignment extends the EC2 deployment by integrating S3 for log archival and IAM roles for secure, keyless access.


🔑 Features Implemented
1. Secure S3 Bucket

A private S3 bucket was created to store application logs.

The bucket name is configurable via a Terraform variable to avoid conflicts.

2. IAM Roles for Security (Principle of Least Privilege)

Two IAM roles were created:

Uploader Role (Role B): Can only create bucket objects and upload logs, with no read/download permissions. Attached to the EC2 instance.

Read-Only Role (Role A): Can only list files in the bucket, used for verification.

3. Keyless EC2 to S3 Access

The EC2 instance uses an IAM Instance Profile to assume the Uploader Role.

This allows the instance to interact with S3 without storing AWS keys locally.

4. Automated Log Upload

The user_data.sh script was updated to:

Start the Java application.

Upload logs automatically to s3://<bucket-name>/app/logs.

5. Log Retention Policy

An S3 Lifecycle Rule automatically deletes logs after 7 days.

This helps optimize costs and prevents clutter.

6. Code Organization

Terraform configuration is modularized:

main.tf – EC2 and networking

iam.tf – IAM roles and policies

s3.tf – S3 bucket and lifecycle rules




Verification using the Read-Only Role
The final step of the assignment was to ensure the security policies were working correctly by using the specially created read-only 'Auditor' role.


This was tested using the "Switch Role" functionality within the AWS Management Console. By providing the AWS Account ID and the specific name of the auditor IAM role (e.g., Dev-s3-auditor-role), I temporarily adopted its limited permissions to interact with the S3 service.



📘 Assignment 3: CI/CD with GitHub Actions, ELB, and a Pull-Based Deployment Model

This assignment evolves the project into a complete CI/CD pipeline, building a highly available and self-updating system.
The core responsibility shifts from the server building the code (push model) to a CI/CD pipeline building the code and the servers automatically pulling the latest version (pull model).

🏗️ New Architecture

The infrastructure was significantly upgraded for resilience and scalability:

🌐 Application Load Balancer (ELB):
Distributes incoming traffic across multiple EC2 instances in a Round Robin fashion, ensuring high availability.

🖥️ Multiple EC2 Instances:
The system now supports a configurable number of EC2 instances (1 + n), automatically registered with the Load Balancer’s target group.

📂 Three Distinct S3 Buckets:

JAR Bucket: Stores the compiled Java application (.jar file). EC2 instances watch this bucket for updates.

EC2 Logs Bucket: Collects logs from each individual EC2 instance in folders named by instance ID.

ELB Logs Bucket: Stores Application Load Balancer access logs for traffic analysis.

🔄 Self-Updating Deployment Strategy (Pull Model)

A robust pull-based mechanism was implemented:

📡 S3 Polling:
Each EC2 instance runs a background script that polls the JAR S3 bucket every 5 minutes.

⚡ Automatic Updates:
When a new/updated .jar file is detected:

The old application process is terminated.

The new version is automatically started.

👉 This makes the entire server fleet self-updating without any direct SSH commands from the CI/CD pipeline.

⚙️ CI/CD Workflow with GitHub Actions

The CI/CD pipeline is now focused and streamlined:

🖱️ Manual Trigger:
GitHub Action is configured with a workflow_dispatch trigger → developers can start a deployment manually from the GitHub UI.

🏗️ Build and Upload:

Builds Java source code into a .jar file using Maven.

Uploads the final .jar artifact to the JAR S3 bucket.

This upload is the event that triggers self-updating on EC2 instances.

🔐 Security and Logging Enhancements

📁 Segregated Policies:
All IAM & S3 policies are now managed in a dedicated /policy directory for better organization.

🔒 Principle of Least Privilege:

EC2 instances have specific IAM roles with two policies:

Read-only for JAR bucket.

Write-only for EC2 logs bucket.

🛡️ Service-Level Permissions:
ELB logs bucket has a dedicated S3 Bucket Policy, allowing ELB service to write its access logs.

👤 Auditor Role:
An "Auditor" IAM role was created (from Assignment 2).

Lets a human securely assume the role in AWS Console.

Grants read-only access to all three S3 buckets for verification.





✅ How to Verify
Since the bucket is private, you won’t see logs by default. Instead, follow these steps:

Use Role A (Read-Only Role):
Assume the role or log in with it to test.

Access Bucket via Direct URL:
Open the following in your browser:

https://s3.console.aws.amazon.com/s3/buckets/<your-unique-bucket-name>


Replace <your-unique-bucket-name> with the actual bucket name (e.g., private-key1q2w3e).

Check Logs:
You should see uploaded logs inside the app/logs folder.

🗑️ Cleanup

Once done, destroy the infrastructure to avoid charges:

terraform destroy -auto-approve
