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
                // Uses the native "aws" CLI installed inside the Jenkins
                // container instead of a sidecar "amazon/aws-cli" container.
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('5. Deploy App') {
            steps {
                // Uses the native aws CLI (already installed inside the
                // Jenkins container) so the kubeconfig is written directly
                // to the real $WORKSPACE with no docker-sidecar path
                // translation issues.
                sh '''
                set -e
                rm -f $WORKSPACE/kubeconfig.yaml

                aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $WORKSPACE/kubeconfig.yaml

                S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text | awk '{print $1}')
                DB_PASS=$(aws secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                DB_HOST=$(aws rds describe-db-instances --db-instance-identifier dev-mysql-db --query "DBInstances[0].Endpoint.Address" --output text)

                if [ -z "$DB_PASS" ] || [ -z "$DB_HOST" ]; then
                  echo "ERROR: Failed to retrieve DB credentials or endpoint from AWS. Aborting."
                  exit 1
                fi

                helm upgrade --install nti-release ./helm --kubeconfig $WORKSPACE/kubeconfig.yaml \
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

        // NEW STAGE: deploys Prometheus + Grafana + Loki using the values
        // files checked into this repo under monitoring/. Uses
        // "helm upgrade --install" so it is safe to run on every build --
        // if nothing changed, Helm does nothing. Grafana is exposed via
        // LoadBalancer (same mechanism already used for the app frontend),
        // which requires NO Terraform or security group changes. Loki is
        // registered as a Grafana data source automatically via the
        // additionalDataSources setting in monitoring/values-prometheus.yaml
        // -- no manual "Add data source" step is needed after a rebuild.
        stage('6. Deploy Monitoring Stack') {
            steps {
                sh '''
                set -e
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
                helm repo add grafana https://grafana.github.io/helm-charts --force-update
                helm repo update

                kubectl --kubeconfig $WORKSPACE/kubeconfig.yaml create namespace monitoring --dry-run=client -o yaml | kubectl --kubeconfig $WORKSPACE/kubeconfig.yaml apply -f -

                helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
                  --kubeconfig $WORKSPACE/kubeconfig.yaml \
                  --namespace monitoring \
                  -f monitoring/values-prometheus.yaml \
                  --wait --timeout 10m

                helm upgrade --install loki-stack grafana/loki-stack \
                  --kubeconfig $WORKSPACE/kubeconfig.yaml \
                  --namespace monitoring \
                  -f monitoring/values-loki.yaml \
                  --wait --timeout 10m
                '''
            }
        }

        stage('7. Deployment Complete') {
            steps {
                sh '''
                echo "----------------------------------------------------------"
                echo "DEPLOYMENT COMPLETE!"
                echo "----------------------------------------------------------"
                '''
            }
        }
    }

    post {
        success {
            script {
                // --- App frontend ELB (existing, unchanged logic) ---
                def elbUrl = sh(
                    script: '''
                    set -e
                    export KUBECONFIG="$WORKSPACE/kubeconfig.yaml"
                    for i in $(seq 1 60); do
                      SVC_LINE=$(kubectl get svc -A --no-headers 2>/dev/null | awk '$2 ~ /frontend$/ {print $1, $2; exit}')
                      SERVICE_NAMESPACE=$(echo "$SVC_LINE" | awk '{print $1}')
                      SERVICE_NAME=$(echo "$SVC_LINE" | awk '{print $2}')

                      if [ -n "$SERVICE_NAME" ] && [ -n "$SERVICE_NAMESPACE" ]; then
                        ELB_URL=$(kubectl get svc "$SERVICE_NAME" -n "$SERVICE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
                        if [ -n "$ELB_URL" ]; then
                          echo "$ELB_URL"
                          exit 0
                        fi
                      fi

                      echo "Waiting for frontend LoadBalancer..." >&2
                      kubectl get svc -A >&2 2>/dev/null || true
                      kubectl get pods -A >&2 2>/dev/null || true
                      sleep 15
                    done

                    echo "Frontend ELB URL is still not ready. Current services:" >&2
                    kubectl get svc -A >&2 2>/dev/null || true
                    exit 0
                    ''',
                    returnStdout: true
                ).trim()

                if (elbUrl) {
                    elbUrl = elbUrl.readLines().findAll { it.trim() }.last().trim()
                }

                if (elbUrl) {
                    echo "SUCCESS! WEB APP: http://${elbUrl}"
                    currentBuild.description = "App URL: http://${elbUrl}"
                } else {
                    echo "Frontend ELB URL is still not ready."
                }

                // --- NEW: Grafana ELB (separate, independent lookup, same
                // pattern as above. Kept fully separate from the frontend
                // logic above so a Grafana lookup issue can never affect
                // the app URL reporting that already works. ---
                def grafanaUrl = sh(
                    script: '''
                    set -e
                    export KUBECONFIG="$WORKSPACE/kubeconfig.yaml"
                    for i in $(seq 1 40); do
                      GRAFANA_HOST=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
                      if [ -n "$GRAFANA_HOST" ]; then
                        echo "$GRAFANA_HOST"
                        exit 0
                      fi
                      echo "Waiting for Grafana LoadBalancer..." >&2
                      sleep 15
                    done
                    exit 0
                    ''',
                    returnStdout: true
                ).trim()

                if (grafanaUrl) {
                    grafanaUrl = grafanaUrl.readLines().findAll { it.trim() }.last().trim()
                }

                if (grafanaUrl) {
                    echo "GRAFANA URL: http://${grafanaUrl} (user: admin)"
                    currentBuild.description = "${currentBuild.description ?: ''} | Grafana: http://${grafanaUrl}"
                } else {
                    echo "Grafana LoadBalancer URL is still not ready."
                }

                // --- Grafana admin password, printed here alongside the
                // URL so both pieces of login info show up together at
                // the end of the build, instead of mid-build noise. ---
                def grafanaPass = sh(
                    script: '''
                    set -e
                    export KUBECONFIG="$WORKSPACE/kubeconfig.yaml"
                    kubectl get secret \
                      --namespace monitoring \
                      -l app.kubernetes.io/component=admin-secret \
                      -o jsonpath="{.items[0].data.admin-password}" 2>/dev/null | base64 --decode || true
                    ''',
                    returnStdout: true
                ).trim()

                if (grafanaPass) {
                    echo "GRAFANA PASSWORD: ${grafanaPass}"
                }
            }
        }
    }
}