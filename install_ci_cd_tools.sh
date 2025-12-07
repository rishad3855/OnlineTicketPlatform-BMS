#!/bin/bash
# Combined script to install all CI/CD tools on an Ubuntu EC2 Agent (Jenkins, Docker, AWS CLI, Trivy, SonarQube Scanner, OWASP DC)

# Define Versions
JAVA_VERSION="17"
NODE_VERSION="23"
SCANNER_VERSION="5.0.1.3006"
ODC_VERSION="9.0.9" # Check for the latest release on GitHub

echo "=========================================================="
echo " Starting CI/CD Toolchain Installation"
echo "=========================================================="

# --- Function to handle package installations ---
install_package() {
    PACKAGE=$1
    echo "--- Installing ${PACKAGE} ---"
    sudo apt install -y $PACKAGE
}

# --- 1. System Update and Prerequisites ---
echo "--- 1. System Update and Unzip Utility ---"
sudo apt update -y
install_package unzip
install_package gnupg
install_package lsb-release

# --- 2. Jenkins and Java 17 Installation ---
echo "--- 2. Installing Java ${JAVA_VERSION} and Jenkins ---"
install_package openjdk-${JAVA_VERSION}-jre

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update -y
install_package jenkins

sudo systemctl start jenkins
sudo systemctl enable jenkins
echo "Jenkins is running on port 8080."

# . NodeJS Installation ---
echo "--- 3. Installing NodeJS v${NODE_VERSION} (Required for 'npm install') ---"
NODE_MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1)

# Add Nodesource repository for the specified major version
curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | sudo -E bash -
install_package nodejs
node -v # Quick verification
apt install nodejs -y
echo "NodeJS installed successfully."

# --- 3. Docker Installation and Configuration ---
echo "--- 3. Installing Docker Engine ---"
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
install_package docker-ce docker-ce-cli containerd.io

sudo systemctl start docker
sudo systemctl enable docker

echo "--- Configuring Jenkins User for Docker Permissions ---"
# Add 'jenkins' user to 'docker' group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# --- 4. AWS CLI Installation ---
echo "--- 4. Installing AWS CLI v2 ---"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws
aws --version
echo "AWS CLI installed. Remember to attach an IAM Role to the EC2 instance."

# --- 9. eksctl Installation (Optional but highly recommended for EKS management) ---
echo "---Installing eksctl ---"
# Download and install the official eksctl binary
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
sudo chown root:root /usr/local/bin/eksctl
sudo chmod +x /usr/local/bin/eksctl


# --- 5. Trivy Installation ---
echo "--- 5. Installing Trivy Security Scanner ---"
# Add Trivy repository
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

sudo apt update -y
install_package trivy
trivy --version

# --- 6. SonarQube Scanner Installation ---
 Install SonarQube using Docker
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

# --- 10. Ansible Installation and Configuration --
echo "--- 10. Installing Ansible and Kubernetes Collection ---"
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
ansible-galaxy collection install kubernetes.core

# Install pip (Python package manager) first if it's not present
sudo apt install -y python3-pip
# Install the official Kubernetes Python client library
pip3 install kubernetes

# --- 7. OWASP Dependency-Check Installation ---
echo "--- 7. Installing OWASP Dependency-Check CLI v${ODC_VERSION} ---"
wget https://github.com/jeremylong/DependencyCheck/releases/download/v${ODC_VERSION}/dependency-check-${ODC_VERSION}-release.zip
unzip dependency-check-${ODC_VERSION}-release.zip
sudo mv dependency-check /opt/dependency-check
sudo ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
rm dependency-check-${ODC_VERSION}-release.zip
dependency-check --version

echo "=========================================================="
echo " 🚨 FINAL VERSION VERIFICATION 🚨"
echo "=========================================================="

# --- Check Java (JDK) Version ---
echo "--- Java (JDK) Verification ---"
java -version 2>&1 | head -n 1
# Expected: openjdk version "17.0.x"

# --- Check NodeJS Version ---
echo "--- NodeJS Verification ---"
node -v
# Expected: v23.x.x

# --- Check Docker Version ---
echo "--- Docker Verification ---"
docker --version
# Expected: Docker version 24.x.x or similar

# --- Check AWS CLI Version ---
echo "--- AWS CLI Verification ---"
aws --version | head -n 1
# Expected: aws-cli/2.x.x
echo "--- Ansible Verification ---"
ansible --version | head -n 1
# --- Check Trivy Version ---
echo "--- Trivy Verification ---"
trivy --version | head -n 1
# Expected: Version: 0.50.x or similar

echo "--- eksctl Installation Complete ---"
eksctl version

# --- Check SonarQube Scanner container ---
docker ps

# --- Check OWASP Dependency-Check Version ---
echo "--- OWASP Dependency-Check Verification ---"
/usr/local/bin/dependency-check --version | head -n 2
# Expected: OWASP Dependency-Check Core x.x.x (matching $ODC_VERSION)

# --- Check Kubectl (Optional but essential for deployment) ---
# Assuming kubectl was manually installed per prior instructions
echo "--- Kubectl Verification (if installed) ---"
if command -v kubectl &> /dev/null; then
    kubectl version --client --short
else
    echo "kubectl not found. Install separately for EKS deployment."
fi

cat /var/lib/jenkins/secrets/initialAdminPassword
cat /opt/sonarqube/conf/sonar.properties


echo "=========================================================="
echo " ALL CI/CD TOOL INSTALLATIONS COMPLETE."

