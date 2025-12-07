pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node23'
    }

    environment {
        // !!! REPLACE with your actual AWS Account ID !!!
        AWS_ACCOUNT_ID = '463000837460' 
        AWS_REGION     = 'ap-south-1'    
        ECR_REPO_NAME  = 'bookmyshow-app'
        IMAGE_TAG      = "${env.BUILD_NUMBER}" 
        ECR_URI        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
        
        SCANNER_HOME = tool 'sonar-scanner'
        EKS_CLUSTER_NAME = 'bms-eks'
        ANSIBLE_PLAYBOOK = './ansible/deploy_to_eks.yml'
        K8S_MANIFEST     = './k8s/deployment.yml.j2'
    }

    stages {
        stage('Clean Workspace') {
            steps { cleanWs() }
        }

        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/rishad3855/OnlineTicketPlatform-BMS.git'
                sh 'ls -la'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh ''' 
                    ${SCANNER_HOME}/bin/sonar-scanner \
                         -Dsonar.projectName=BMS \
                         -Dsonar.projectKey=BMS
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                cd bookmyshow-app
                if [ -f package.json ]; then
                    rm -rf node_modules package-lock.json
                    npm install
                else
                    echo "Error: package.json not found in bookmyshow-app! Exiting."
                    exit 1
                fi
                '''
            }
        }

         stage('OWASP FS SCAN') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit -n', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
    }
}

        stage('Trivy FS Scan') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }
        
        stage('Docker Build & Push to ECR') {
            steps {
                script {
                    // Requires 'aws-eks-credentials' (IAM credentials) configured in Jenkins
                    withCredentials([aws(credentialsId: 'aws-eks-credentials', roleBindings: [])]) { 
                        sh """
                        # 1. AWS ECR Authentication
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        
                        # 2. Build the Docker Image
                        docker build --no-cache -t ${ECR_REPO_NAME}:${IMAGE_TAG} -f bookmyshow-app/Dockerfile bookmyshow-app
                        
                        # 3. Tag and Push to ECR
                        docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
                        docker push ${ECR_URI}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('Deploy to EKS Cluster (via Ansible)') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-eks-credentials']]) {
                    sh """
                    echo "Configuring kubectl for EKS cluster: ${EKS_CLUSTER_NAME}"
                    # Update Kubeconfig, granting Jenkins machine access to EKS
                    aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --kubeconfig kubeconfig 
                    
                    echo "Executing Ansible Playbook..."
                    # Execute Ansible, passing the dynamic image tag and ECR URI
                    ansible-playbook -i localhost, ${ANSIBLE_PLAYBOOK} \
                        -e "kubeconfig_path=${WORKSPACE}/kubeconfig" \
                        -e "image_tag=${IMAGE_TAG}" \
                        -e "ecr_uri=${ECR_URI}"
                    
                    echo "Deployment verification:"
                    kubectl --kubeconfig ${WORKSPACE}/kubeconfig get svc ticketing-app-service
                    """
                }
            }
        }
    }
    }
    post {
        always {
            emailext attachLog: true,
                subject: "'${currentBuild.result}'",
                body: "Project: ${env.JOB_NAME}<br/>" +
                      "Build Number: ${env.BUILD_NUMBER}<br/>" +
                      "URL: ${env.BUILD_URL}<br/>",
                to: 'ameen.aws.3855@gmail.com.com',
                attachmentsPattern: 'trivyfs.txt'
        }
    }
}

