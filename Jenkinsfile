pipeline {
    agent any
    triggers { pollSCM('* * * * *') }

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

        stage('2. SonarQube Analysis') {
            steps {
                sh "docker run --rm -e SONAR_HOST_URL=${SONAR_HOST_URL} -v '${WORKSPACE}:/usr/src' sonarsource/sonar-scanner-cli -Dsonar.projectKey=nti-devops-app -Dsonar.projectName=nti-devops-app -Dsonar.sources=. -Dsonar.exclusions=terraform/**,ansible/**,helm/** -Dsonar.qualitygate.wait=true"
            }
        }

        stage('3. Build & Scan Images') {
            steps {
                sh "docker build -t ${FRONTEND_ECR}:${BUILD_NUMBER} ./docker/frontend"
                sh "docker build -t ${BACKEND_ECR}:${BUILD_NUMBER} ./docker/backend"
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --exit-code 0 ${FRONTEND_ECR}:${BUILD_NUMBER}"
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --exit-code 0 ${BACKEND_ECR}:${BUILD_NUMBER}"
            }
        }

        stage('4. Push to ECR') {
            steps {
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('5. Deploy App & Monitoring') {
            steps {
                sh '''
                # 1. Prepare Connection
                aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $WORKSPACE/kubeconfig
                
                # 2. Fetch Secrets
                S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text)
                DB_PASS=$(aws secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                DB_HOST=$(aws rds describe-db-instances --db-instance-identifier dev-mysql-db --query "DBInstances[0].Endpoint.Address" --output text)
                
                # 3. Deploy Prometheus Stack (Step 6)
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo add grafana https://grafana.github.io/helm-charts
                helm repo update
                
                helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --kubeconfig $WORKSPACE/kubeconfig \
                  --namespace monitoring --create-namespace \
                  --set grafana.adminPassword="admin" \
                  --set prometheusOperator.admissionWebhooks.enabled=false \
                  --set prometheusOperator.admissionWebhooks.patch.enabled=false \
                  --set prometheusOperator.tls.enabled=false
                
                helm upgrade --install loki grafana/loki-stack --kubeconfig $WORKSPACE/kubeconfig --namespace monitoring --set loki.persistence.enabled=false

                # 4. Deploy Application
                helm upgrade --install nti-release ./helm --kubeconfig $WORKSPACE/kubeconfig \
                  --set frontend.image.repository=$FRONTEND_ECR \
                  --set backend.image.repository=$BACKEND_ECR \
                  --set frontend.image.tag=$BUILD_NUMBER \
                  --set backend.image.tag=$BUILD_NUMBER \
                  --set s3_bucket_name=$S3_BUCKET \
                  --set database.password=$DB_PASS \
                  --set database.host=$DB_HOST
                '''
            }
        }

        stage('6. Expose Grafana') {
            steps {
                sh '''
                set +e
                export KUBECONFIG="$WORKSPACE/kubeconfig"
                export AWS_SHARED_CREDENTIALS_FILE=/var/jenkins_home/.aws/credentials
                export AWS_CONFIG_FILE=/var/jenkins_home/.aws/config

                HOST_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
                kubectl -n monitoring get svc prometheus-grafana >/dev/null 2>&1 || true

                pkill -f "kubectl port-forward.*prometheus-grafana" || true
                nohup kubectl port-forward --address 0.0.0.0 -n monitoring svc/prometheus-grafana 3000:80 > grafana-port-forward.log 2>&1 &
                sleep 8

                if curl -sf http://127.0.0.1:3000/ >/dev/null 2>&1; then
                  echo "----------------------------------------------------------"
                  echo "GRAFANA URL: http://${HOST_IP}:3000"
                  echo "----------------------------------------------------------"
                else
                  echo "----------------------------------------------------------"
                  echo "Grafana port-forward was started, but the UI did not become reachable yet."
                  echo "Check the logs at $WORKSPACE/grafana-port-forward.log"
                  echo "GRAFANA URL (if available): http://${HOST_IP}:3000"
                  echo "----------------------------------------------------------"
                fi
                '''
            }
        }
    }

    post {
        success {
            script {
                def elbUrl = sh(
                    script: '''
                    set -e
                    export KUBECONFIG="$WORKSPACE/kubeconfig"
                    for i in $(seq 1 30); do
                      ELB_URL=$(kubectl get svc nti-release-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
                      if [ -n "$ELB_URL" ]; then
                        echo "$ELB_URL"
                        exit 0
                      fi
                      sleep 10
                    done
                    exit 0
                    ''',
                    returnStdout: true
                ).trim()

                if (elbUrl) {
                    echo "SUCCESS! WEB APP: http://${elbUrl}"
                    currentBuild.description = "App URL: http://${elbUrl}"
                } else {
                    echo "Frontend ELB URL is still not ready."
                }
            }
        }
    }
}