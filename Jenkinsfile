pipeline {
    agent any

    environment {
        GEM_HOME = "${env.WORKSPACE}/.gems"
        PATH = "${env.GEM_HOME}/bin:/usr/bin:${env.PATH}"
        SNYK_TOKEN = credentials('snyk-api-token')
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

        stage('Security Scan (Snyk)') {
            steps {
                echo 'Running Snyk vulnerability scan...'
                sh '''
                    npm install -g snyk
                    snyk auth "$SNYK_TOKEN"
                    snyk test --json-file-output=snyk-sca.json || true
                    snyk code test --json-file-output=snyk-code.json || true
                '''
                script {
                    def scaStatus  = sh(script: 'snyk test --severity-threshold=high', returnStatus: true)
                    def codeStatus = sh(script: 'snyk code test --severity-threshold=high', returnStatus: true)

                    // Snyk CLI exit codes: 0 = clean, 1 = issues at/above threshold, 2 = CLI/run error
                    if (scaStatus == 2 || codeStatus == 2) {
                        error 'Snyk scan failed to execute — check snyk-api-token credential / CLI install'
                    }

                    def scaHighCritical  = (scaStatus == 1)
                    def sastHighCritical = (codeStatus == 1)

                    if (scaHighCritical) {
                        echo 'High/critical dependency vulnerabilities found — auto-patching Gemfile for this build only'
                        sh '''
                            ruby scripts/autofix_gems.rb snyk-sca.json Gemfile
                            bundle update $(ruby scripts/autofix_gems.rb --print-updated-packages snyk-sca.json Gemfile)
                        '''
                        archiveArtifacts artifacts: 'Gemfile,Gemfile.lock', allowEmptyArchive: true
                        unstable('High/critical dependency vulnerabilities were auto-patched for THIS BUILD ONLY (see archived Gemfile/Gemfile.lock). Nothing was committed — a maintainer must review and commit the fix.')
                    }

                    if (sastHighCritical) {
                        error 'High/critical vulnerabilities found in first-party code (Snyk Code). These cannot be auto-fixed by the pipeline — manual review required.'
                    }

                    if (!scaHighCritical && !sastHighCritical) {
                        echo 'No high/critical vulnerabilities — recording findings report'
                        def authorEmail = sh(script: "git log -1 --format='%ae'", returnStdout: true).trim()
                        def username = authorEmail.split('@')[0]
                        sh "mkdir -p security-reports"
                        sh "ruby scripts/generate_snyk_report.rb snyk-sca.json snyk-code.json security-reports/${username}.md"
                        sh """
                            git config user.name 'jenkins-security-bot'
                            git config user.email 'ci-security-bot@drjpp89.github.io'
                            git add security-reports/${username}.md
                        """
                        def hasChanges = (sh(script: 'git diff --cached --quiet', returnStatus: true) != 0)
                        if (hasChanges) {
                            sh "git commit -m 'chore(security): Snyk findings report for ${username}'"
                            def branch = env.BRANCH_NAME ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                            sshagent(['github-push-key']) {
                                sh "git push origin HEAD:${branch}"
                            }
                        } else {
                            echo 'Report unchanged since last run — nothing to commit.'
                        }
                    }
                }
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
