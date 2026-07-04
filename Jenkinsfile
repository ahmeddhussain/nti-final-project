pipeline {
    agent any

    triggers {
        cron('* * * * *') // SCM Polling: automatically checks GitHub every minute
    }

    environment {
        AWS_ACCOUNT_ID = '800770414458' 
        AWS_REGION     = 'us-east-1'
        CLUSTER_NAME   = 'nti-eks-cluster'
        SONAR_HOST_URL = 'http://172.17.0.1:9000'
        
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
                sh "docker build -t ${FRONTEND_ECR}:${BUILD_NUMBER} ./docker/frontend"
                
                echo 'Scanning Frontend Image with Trivy...'
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
                sh "docker build -t ${BACKEND_ECR}:${BUILD_NUMBER} ./docker/backend"
                
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
                sh """
                docker run --rm \
                  -v /home/ubuntu/.aws:/root/.aws \
                  amazon/aws-cli ecr get-login-password --region ${AWS_REGION} | \
                  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('6. Deploy to EKS via Helm') {
            steps {
                echo 'Deploying application to EKS cluster...'
                sh """
                # 1. Generate the EKS kubeconfig file in our workspace (Fixed path!)
                docker run --rm \
                  -v /home/ubuntu/.aws:/root/.aws \
                  -v "${WORKSPACE}:/apps" \
                  amazon/aws-cli eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} --kubeconfig /apps/kubeconfig
                
                # 2. Fetch the S3 Bucket Name and DB Password dynamically from AWS (Fixed paths!)
                S3_BUCKET=\&((docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli s3 api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text))
                DB_PASS=\&((docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+'))
                
                # 3. Use the Helm container to deploy, mounting our generated kubeconfig
                docker run --rm \
                  -v "${WORKSPACE}:/apps" \
                  -w /apps \
                  alpine/helm:3.12.0 --kubeconfig /apps/kubeconfig upgrade --install nti-release ./helm \
                  --set frontend.image.tag=${BUILD_NUMBER} \
                  --set backend.image.tag=${BUILD_NUMBER} \
                  --set s3_bucket_name=\\\$S3_BUCKET \
                  --set database.password=\\\$DB_PASS
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