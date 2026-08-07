pipeline {
    agent any

    environment {
        GEM_HOME = "${env.WORKSPACE}/.gems"
        PATH = "${env.GEM_HOME}/bin:/usr/bin:${env.PATH}"
    }

    triggers {
        // Polls GitHub every 5 minutes since Jenkins isn't reachable
        // for a real push webhook in this environment.
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }

        stage('Setup Ruby Environment') {
            steps {
                echo 'Setting up Ruby environment...'
                sh '''
                    # Check Ruby version
                    ruby --version

                    # Install bundler if not present
                    if ! command -v bundle &> /dev/null; then
                        echo "Installing bundler..."
                        gem install bundler --no-document
                    fi

                    bundle --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installing Jekyll dependencies...'
                sh '''
                    bundle config set --local path ${GEM_HOME}
                    bundle install
                '''
            }
        }

        stage('Build Site') {
            steps {
                echo 'Building Jekyll site...'
                sh 'bundle exec jekyll build'
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh '''
                    # Check if _site directory was created
                    if [ -d "_site" ]; then
                        echo "Build successful: _site directory exists"
                        ls -la _site
                    else
                        echo "Build failed: _site directory not found"
                        exit 1
                    fi
                '''
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deployment stage - Ready to deploy to hosting'
                // Add deployment steps here when ready
                // For now, just archive the build artifacts
                archiveArtifacts artifacts: '_site/**/*', fingerprint: true
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Please check the logs.'
        }
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}
