pipeline {
    agent any

    triggers {
        pollSCM('* * * * *') 
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
        stage('1. Checkout') { steps { checkout scm } }

        stage('2. SonarQube') {
            steps {
                sh "docker run --rm -e SONAR_HOST_URL=${SONAR_HOST_URL} -v '${WORKSPACE}:/usr/src' sonarsource/sonar-scanner-cli -Dsonar.projectKey=nti-devops-app -Dsonar.projectName=nti-devops-app -Dsonar.sources=. -Dsonar.exclusions=terraform/**,ansible/**,helm/**"
            }
        }

        stage('3. Build & Scan Frontend') {
            steps {
                sh "docker build -t ${FRONTEND_ECR}:${BUILD_NUMBER} ./docker/frontend"
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --exit-code 0 --severity HIGH,CRITICAL ${FRONTEND_ECR}:${BUILD_NUMBER}"
            }
        }

        stage('4. Build & Scan Backend') {
            steps {
                sh "docker build -t ${BACKEND_ECR}:${BUILD_NUMBER} ./docker/backend"
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --exit-code 0 --severity HIGH,CRITICAL ${BACKEND_ECR}:${BUILD_NUMBER}"
            }
        }

        stage('5. Push to ECR') {
            steps {
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('6. Deploy to EKS') {
            steps {
                sh '''
                # Generate kubeconfig inside workspace
                aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig kubeconfig
                
                S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text)
                DB_PASS=$(aws secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                DB_HOST=$(aws rds describe-db-instances --db-instance-identifier dev-mysql-db --query "DBInstances[0].Endpoint.Address" --output text)
                
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo add grafana https://grafana.github.io/helm-charts
                helm repo update
                
                helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --kubeconfig kubeconfig --namespace monitoring --create-namespace --set grafana.adminPassword="admin" --set alertmanager.enabled=true --set prometheusOperator.admissionWebhooks.enabled=false --set prometheusOperator.admissionWebhooks.patch.enabled=false --set prometheusOperator.tls.enabled=false
                helm upgrade --install loki grafana/loki-stack --kubeconfig kubeconfig --namespace monitoring --set loki.persistence.enabled=false
                
                helm upgrade --install nti-release ./helm --kubeconfig kubeconfig --set frontend.image.repository=$FRONTEND_ECR --set backend.image.repository=$BACKEND_ECR --set frontend.image.tag=$BUILD_NUMBER --set backend.image.tag=$BUILD_NUMBER --set s3_bucket_name=$S3_BUCKET --set database.password=$DB_PASS --set database.host=$DB_HOST
                '''
            }
        }
    }

    post {
        success {
            sh '''
            # 1. Wait for ELB DNS
            ELB_URL=""
            while [ -z "$ELB_URL" ]; do
              echo "Waiting for ELB DNS..."
              sleep 5
              ELB_URL=$(kubectl get svc nti-release-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --kubeconfig kubeconfig)
            done
            
            # 2. Get active Host IP
            HOST_IP=$(curl -s ifconfig.me)
            
            # 3. START TUNNEL using exact Host path (No substitutions)
            docker rm -f grafana-tunnel || true
            docker run -d \
              --name grafana-tunnel \
              --network host \
              -v /home/ubuntu/.aws:/root/.aws \
              -v /var/lib/docker/volumes/jenkins_home/_data/workspace/nti-final-project_main/kubeconfig:/root/.kube/config \
              --entrypoint "" \
              amazon/aws-cli bash -c "
                curl -fsSL -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl && chmod +x kubectl
                echo 'Starting Self-Healing Tunnel...'
                while true; do
                  ./kubectl port-forward --address 0.0.0.0 -n monitoring svc/prometheus-grafana 3000:80
                  sleep 5
                done
              "
            
            echo ""
            echo "=========================================================="
            echo "SUCCESS! WEB APP: http://${ELB_URL}"
            echo "SUCCESS! GRAFANA: http://${HOST_IP}:3000"
            echo "=========================================================="
            '''
        }
    }
}