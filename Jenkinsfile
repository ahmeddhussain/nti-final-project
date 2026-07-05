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
                // FIX: uses the native "aws" CLI installed inside the Jenkins
                // container instead of a sidecar "amazon/aws-cli" container.
                // This stage happened to work before because it never wrote
                // a file back into $WORKSPACE, but it's changed here too for
                // consistency with stage 5's real fix below.
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('5. Deploy App') {
            steps {
                // FIX (the actual bug): the old version ran
                // "docker run -v $WORKSPACE:/apps amazon/aws-cli ..." via the
                // mounted docker.sock. Since that docker command is executed
                // by the HOST's Docker daemon (not nested inside Jenkins),
                // $WORKSPACE was interpreted as a HOST path, not the path
                // Jenkins itself sees — they are NOT the same location
                // (jenkins_home is a named volume; its real host path is
                // under /var/lib/docker/volumes/jenkins_home/_data/...).
                // Docker silently created an empty, disconnected directory
                // on the host, wrote the kubeconfig there, and it was never
                // visible to Jenkins or Helm. Using the NATIVE aws CLI here
                // (already installed inside the Jenkins container) writes
                // directly to the real $WORKSPACE with no path translation
                // and no sidecar container involved at all.
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

        stage('6. Deployment Complete') {
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

                      # Debug/status noise goes to stderr so it never
                      # contaminates the stdout value Jenkins captures below.
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

                // Defensive: keep only the last non-empty line, in case
                // anything still leaks through onto stdout.
                if (elbUrl) {
                    elbUrl = elbUrl.readLines().findAll { it.trim() }.last().trim()
                }

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