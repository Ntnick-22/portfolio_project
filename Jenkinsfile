pipeline {
    agent any
    
    parameters {
        booleanParam(name: 'PLAN_TERRAFORM', defaultValue: false, description: 'Check to plan Terraform changes')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Check to apply Terraform changes')
        booleanParam(name: 'DESTROY_TERRAFORM', defaultValue: false, description: 'Check to destroy Terraform resources')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Select environment to deploy')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run application tests before deployment')
    }
    
    environment {
        FLASK_ENV = 'production'
        PYTHONPATH = "${WORKSPACE}/app"
        TF_VAR_project_name = "portfolio-dashboard-${params.ENVIRONMENT}"
    }
    
    stages {
        stage('Clean Workspace') {
            steps {
                script {
                    echo "🧹 Cleaning workspace..."
                    deleteDir()
                }
            }
        }
        
        stage('Clone Repository') {
            steps {
                script {
                    echo "📥 Cloning portfolio repository..."
                    // Update with your actual GitHub repository URL
                    git branch: 'main',
                        url: 'https://github.com/yourusername/portfolio-project.git'
                    
                    sh "ls -lart"
                    echo "✅ Repository cloned successfully"
                }
            }
        }
        
        stage('Validate Project Structure') {
            steps {
                script {
                    echo "🔍 Validating project structure..."
                    sh '''
                        echo "Checking required files..."
                        [ -f "app/app.py" ] && echo "✅ Flask app found" || exit 1
                        [ -f "app/requirements.txt" ] && echo "✅ Requirements file found" || exit 1
                        [ -d "app/templates" ] && echo "✅ Templates directory found" || exit 1
                        [ -f "terraform/main.tf" ] && echo "✅ Terraform main file found" || exit 1
                        echo "✅ Project structure validation passed"
                    '''
                }
            }
        }
        
        stage('Install Dependencies & Run Tests') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    echo "🔧 Installing Python dependencies..."
                    sh '''
                        cd app/
                        python3 -m pip install --user -r requirements.txt
                        echo "✅ Dependencies installed"
                    '''
                    
                    echo "🧪 Running application tests..."
                    sh '''
                        cd app/
                        python3 -c "
import app
import json

print('Testing Flask app...')

# Test app initialization
assert app.app is not None, 'Flask app should be initialized'

# Test portfolio data
assert len(app.PORTFOLIO_DATA['skills']) > 0, 'Should have skills data'
assert len(app.PORTFOLIO_DATA['projects']) > 0, 'Should have projects data'

print('✅ All tests passed!')
"
                    '''
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                script {
                    echo "🏗️ Initializing Terraform..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "=================Terraform Init=================="
                                terraform init
                                echo "✅ Terraform initialized successfully"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                script {
                    echo "✅ Validating Terraform configuration..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "=================Terraform Validate=================="
                                terraform validate
                                echo "✅ Terraform configuration is valid"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.PLAN_TERRAFORM }
            }
            steps {
                script {
                    echo "📋 Planning Terraform changes..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "=================Terraform Plan=================="
                                terraform plan -detailed-exitcode
                                echo "✅ Terraform plan completed"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM }
            }
            steps {
                script {
                    echo "🚀 Applying Terraform changes..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "=================Terraform Apply=================="
                                terraform apply -auto-approve
                                echo "✅ Infrastructure deployed successfully"
                                
                                echo "=================Getting Outputs=================="
                                terraform output
                                
                                # Save outputs for later use
                                terraform output -json > terraform-outputs.json
                                cat terraform-outputs.json
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Health Check') {
            when {
                expression { params.APPLY_TERRAFORM }
            }
            steps {
                script {
                    echo "🏥 Performing health check on deployed application..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "Waiting for application to be ready..."
                                sleep 60
                                
                                # Get the website URL from terraform output
                                WEBSITE_URL=$(terraform output -raw website_url)
                                echo "🌐 Testing website: $WEBSITE_URL"
                                
                                # Test health endpoint
                                for i in {1..10}; do
                                    if curl -f "$WEBSITE_URL/api/health" -m 10; then
                                        echo "✅ Health check passed!"
                                        break
                                    else
                                        echo "⏳ Attempt $i failed, retrying in 30 seconds..."
                                        sleep 30
                                    fi
                                    
                                    if [ $i -eq 10 ]; then
                                        echo "❌ Health check failed after 10 attempts"
                                        exit 1
                                    fi
                                done
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.DESTROY_TERRAFORM }
            }
            steps {
                script {
                    echo "💥 Destroying Terraform resources..."
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-crendentails-nick']]) {
                        dir('terraform') {
                            sh '''
                                echo "=================Terraform Destroy=================="
                                terraform destroy -auto-approve
                                echo "✅ Infrastructure destroyed successfully"
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Cleaning up workspace..."
                // Archive terraform outputs if they exist
                archiveArtifacts artifacts: 'terraform/terraform-outputs.json', allowEmptyArchive: true
            }
        }
        
        success {
            script {
                echo "🎉 Pipeline completed successfully!"
                
                // If we deployed, show the URL
                if (params.APPLY_TERRAFORM) {
                    dir('terraform') {
                        script {
                            def websiteUrl = sh(
                                script: "terraform output -raw website_url 2>/dev/null || echo 'URL not available'",
                                returnStdout: true
                            ).trim()
                            
                            if (websiteUrl != 'URL not available') {
                                echo """
🚀 DEPLOYMENT SUCCESSFUL! 🚀

Your portfolio is now live at:
${websiteUrl}

Environment: ${params.ENVIRONMENT}
Domain: portfolio.nt-nick.link (if SSL is configured)

Features deployed:
✅ Flask Portfolio Application
✅ Auto-scaling EC2 instances
✅ Application Load Balancer
✅ DynamoDB visitor counter
✅ CloudWatch monitoring
✅ Route 53 custom domain
✅ SSL certificate
"""
                            }
                        }
                    }
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed! Check the logs above for details."
            }
        }
    }
}
