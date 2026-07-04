pipeline {
    agent any

    triggers {
        // SCM Polling: Automatically polls GitHub every single minute for changes.
        // This replaces the need for webhooks so your changing IP won't break things!
        cron('* * * * *')
    }

    environment {
        // --- UPDATE THESE TWO VARIABLES FOR YOUR AWS ACCOUNT ---
        AWS_ACCOUNT_ID = '800770414458' // Your AWS Account ID
        AWS_REGION     = 'us-east-1'
        
        CLUSTER_NAME   = 'nti-eks-cluster'
        SONAR_HOST_URL = 'http://172.17.0.1:9000' //internal docker host IP for SonarQube container that never changes, so we can use it in the Jenkinsfile without worrying about dynamic IPs    
        // ECR Registry URLs (These are generated dynamically)
        FRONTEND_ECR   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/dev-frontend-app"
        BACKEND_ECR    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/dev-backend-app"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Pulling code from GitHub...'
                checkout scm
            }
        }

        stage('2. SonarQube Quality Analysis') {
            steps {
                echo 'Running Static Code Analysis via SonarQube Container...'
                // Spins up the official Sonar Scanner container on-the-fly
                sh """
                docker run --rm \
                  -e SONAR_HOST_URL=${SONAR_HOST_URL} \
                  -v "${WORKSPACE}:/usr/src" \
                  sonarsource/sonar-scanner-cli \
                  -Dsonar.projectKey=nti-devops-app \
                  -Dsonar.projectName=nti-devops-app \
                  -Dsonar.sources=. \
                  -Dsonar.exclusions=terraform/**,ansible/**,helm/**
                """
            }
        }

        stage('3. Build & Scan Frontend Image') {
            steps {
                echo 'Building Frontend Docker Image...'
                sh "docker build -t ${FRONTEND_ECR}:${BUILD_NUMBER} ./frontend"
                
                echo 'Scanning Frontend Image with Trivy...'
                // Spins up the official Trivy container to scan the newly built image
                sh """
                docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  aquasec/trivy image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  ${FRONTEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('4. Build & Scan Backend Image') {
            steps {
                echo 'Building Backend Docker Image...'
                sh "docker build -t ${BACKEND_ECR}:${BUILD_NUMBER} ./backend"
                
                echo 'Scanning Backend Image with Trivy...'
                sh """
                docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  aquasec/trivy image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('5. Push Images to AWS ECR') {
            steps {
                echo 'Logging into AWS ECR and pushing images...'
                // We use the host's AWS CLI config to log into ECR and push the images
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('6. Deploy to EKS via Helm') {
            steps {
                echo 'Deploying application to EKS cluster...'
                // Updates the EKS connection context and deploys the Helm chart
                sh """
                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                
                # Fetch S3 bucket name and DB password dynamically from AWS
                S3_BUCKET=\$(aws s3 api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text)
                DB_PASS=\$(aws secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                
                # Deploy using Helm
                helm upgrade --install nti-release ./helm \
                  --set frontend.image.tag=${BUILD_NUMBER} \
                  --set backend.image.tag=${BUILD_NUMBER} \
                  --set s3_bucket_name=\$S3_BUCKET \
                  --set database.password=\$DB_PASS
                """
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully! Application is live on EKS! '
        }
        failure {
            echo 'Pipeline failed. Please check the logs for errors. '
        }
    }
}