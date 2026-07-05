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
                # Fixed: Uses the official AWS CLI container to ensure the token is fetched correctly
                docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                docker push ${FRONTEND_ECR}:${BUILD_NUMBER}
                docker push ${BACKEND_ECR}:${BUILD_NUMBER}
                """
            }
        }

        stage('5. Deploy App') {
            steps {
                sh '''
                # 1. Clean and regenerate kubeconfig using the AWS CLI wrapper
                rm -f $WORKSPACE/kubeconfig.yaml
                docker run --rm -v /home/ubuntu/.aws:/root/.aws -v $WORKSPACE:/apps amazon/aws-cli eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig /apps/kubeconfig.yaml
                
                # 2. Fetch Secrets using the AWS CLI wrapper
                S3_BUCKET=$(docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli s3api list-buckets --query "Buckets[?contains(Name, 'access-logs')].Name" --output text)
                DB_PASS=$(docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli secretsmanager get-secret-value --secret-id dev-rds-credentials --query SecretString --output text | grep -oP '"password":"\\K[^"]+')
                DB_HOST=$(docker run --rm -v /home/ubuntu/.aws:/root/.aws amazon/aws-cli rds describe-db-instances --db-instance-identifier dev-mysql-db --query "DBInstances[0].Endpoint.Address" --output text)

                # 3. Deploy Application (Helm works natively!)
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