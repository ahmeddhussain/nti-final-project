pipeline {
    agent any

    triggers {
        pollSCM('* * * * *') // SCM Polling: automatically checks GitHub every minute for changes
    }

    environment {
        AWS_ACCOUNT_ID = '800770414458' // Your verified AWS Account ID
        AWS_REGION     = 'us-east-1'
        CLUSTER_NAME   = 'nti-eks-cluster'
        
        // Static internal Docker gateway URL. Never changes on rebuild!
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
                echo 'Running Static Code Analysis...'
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
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('6. Deploy to EKS via Helm') {
            steps {
                echo 'Deploying application and monitoring stack to EKS cluster...'
                sh '''
                # 1. Update EKS Connection context natively
                aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig kubeconfig
                
                # 2. Fetch variables dynamically from AWS
                S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text)
                DB_PASS=$(aws secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                
                # 3. Deploy application via Helm natively
                helm upgrade --install nti-release ./helm --kubeconfig kubeconfig \
                  --set frontend.image.tag=$BUILD_NUMBER \
                  --set backend.image.tag=$BUILD_NUMBER \
                  --set s3_bucket_name=$S3_BUCKET \
                  --set database.password=$DB_PASS
                
                # 4. Add official Prometheus & Grafana Repositories
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo add grafana https://grafana.github.io/helm-charts
                helm repo update
                
                # 5. Automatically deploy Prometheus & Grafana (ClusterIP keeps it secure & free)
                helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --kubeconfig kubeconfig \
                  --namespace monitoring \
                  --create-namespace \
                  --set grafana.adminPassword="admin" \
                  --set alertmanager.enabled=true
                
                # 6. Automatically deploy Loki (Loki Stack for Logs)
                helm upgrade --install loki grafana/loki-stack --kubeconfig kubeconfig \
                  --namespace monitoring \
                  --set loki.persistence.enabled=false
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully! 🎉'
            sh '''
            # 1. Fetch the public ELB DNS name dynamically for the Frontend app
            # (We use a robust while-loop to wait for AWS to generate the DNS)
            ELB_URL=""
            while [ -z "$ELB_URL" ]; do
              echo "Waiting for AWS to assign Public ELB DNS..."
              sleep 5
              ELB_URL=$(kubectl get svc nti-release-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --kubeconfig kubeconfig)
            done
            
            # 2. Fetch your EC2 server's active AWS public IP dynamically
            HOST_IP=$(curl -s ifconfig.me)
            
            # 3. AUTOMATION: Destroy any old background tunnels to prevent port conflicts
            docker rm -f grafana-tunnel || true
            
            # 4. AUTOMATION: Launch a tiny helper container to silently tunnel Grafana to host port 3000
            docker run -d \
              --name grafana-tunnel \
              --network host \
              -v "$(pwd)/kubeconfig:/config" \
              bitnami/kubectl:latest \
              --kubeconfig /config port-forward --address 0.0.0.0 -n monitoring svc/prometheus-grafana 3000:80
            
            echo ""
            echo "=========================================================="
            echo "1. Your Web Application is live on AWS EKS!"
            echo "http://${ELB_URL}"
            echo "=========================================================="
            echo ""
            echo "=========================================================="
            echo "2. Your Grafana Monitoring Dashboard is live on AWS EKS!"
            echo "http://${HOST_IP}:3000"
            echo "Credentials: admin / admin"
            echo "=========================================================="
            '''
        }
        failure {
            echo 'Pipeline failed. Please check the logs for errors. ❌'
        }
    }
}