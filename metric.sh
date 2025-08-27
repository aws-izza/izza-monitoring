#!/bin/sh

# --- Variables ---
HELM_RELEASE_NAME="izza-prometheus"
NAMESPACE="metric"
PROMETHEUS_VALUES_FILE="prometheus-values.yaml"
ALERTMANAGER_VALUES_FILE="alertmanager.yaml"
DASHBOARD_CONFIGMAP_FILE="my-grafana-dashboard.yaml"
SLACK_SECRET_NAME="alertmanager-slack-webhook"


# --- Helper Functions for Colored Output ---
info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

warn() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}


install_prerequisites() {
    info "Checking for prerequisites..."

    # 1. Install kubectl
    if ! command -v kubectl &> /dev/null; then
        info "kubectl not found. Installing..."
        curl -LO "https://dl.ks.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        success "kubectl installed successfully."
    else
        success "kubectl is already installed."
    fi

    # 2. Install Helm
    if ! command -v helm &> /dev/null; then
        info "Helm not found. Installing..."
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh
        ./get_helm.sh
        rm get_helm.sh
        success "Helm installed successfully."
    else
        success "Helm is already installed."
    fi

    # 3. Install eksctl
    if ! command -v eksctl &> /dev/null; then
        info "eksctl not found. Installing..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin
        success "eksctl installed successfully."
    else
        success "eksctl is already installed."
    fi

    # 4. Install AWS CLI v2
    if ! command -v aws &> /dev/null; then
        info "AWS CLI not found. Installing..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
        success "AWS CLI installed successfully."
    else
        success "AWS CLI is already installed."
    fi

    info "All prerequisites are satisfied."

}

create_slack_secret() {
    info "Checking for Slack Webhook URL and creating secret..."

    # Check if the SLACK_WEBHOOK_URL environment variable is set.
    # If not, prompt the user to enter it securely.
    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        warn "Environment variable SLACK_WEBHOOK_URL is not set."
        # Use -s to hide the input
        read -sp "Please enter your Slack Webhook URL: " SLACK_WEBHOOK_URL
        echo # Add a newline after the hidden input
    fi
    # Check if the URL is empty after the prompt
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        error "Slack Webhook URL cannot be empty. Aborting."
    fi

    # Use --dry-run to check if the secret already exists, then decide to create or patch.
    if kubectl get secret ${SLACK_SECRET_NAME} -n ${NAMESPACE} &> /dev/null; then
        info "Secret '${SLACK_SECRET_NAME}' already exists. Patching with new value..."
        kubectl create secret generic ${SLACK_SECRET_NAME} \
          --from-literal=SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL" \
          -n ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    else
        info "Creating new secret '${SLACK_SECRET_NAME}'..."
        kubectl create secret generic ${SLACK_SECRET_NAME} \
          --from-literal=SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL" \
          -n ${NAMESPACE}
    fi
    
    # Unset the variable so it doesn't linger in the shell's history
    unset SLACK_WEBHOOK_URL
    success "Slack webhook secret has been configured."
}



configure_helm_repos() {
    info "Adding and updating Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    success "Helm repositories are configured."
}

deploy_monitoring_stack() {
    info "Deploying/upgrading kube-prometheus-stack..."
    
    # Using 'helm upgrade --install' makes this command work for both initial installs and subsequent updates.
    # The --atomic flag ensures that if the upgrade fails, it rolls back to the last known good state.
    helm upgrade --install ${HELM_RELEASE_NAME} prometheus-community/kube-prometheus-stack \
      --namespace ${NAMESPACE} \
      --create-namespace \
      -f ${PROMETHEUS_VALUES_FILE} \
      -f ${ALERTMANAGER_VALUES_FILE} \
      --set fullnameOverride=prometheus \
      --atomic

    success "kube-prometheus-stack deployment initiated successfully."
}

# Function to deploy custom Grafana dashboards
deploy_custom_dashboards() {
    info "Applying custom Grafana dashboard ConfigMap..."

    if [ -f "$DASHBOARD_CONFIGMAP_FILE" ]; then
        kubectl apply -f ${DASHBOARD_CONFIGMAP_FILE} --namespace ${NAMESPACE}
        success "Custom dashboard ConfigMap applied successfully."
    else
        warn "Dashboard ConfigMap file ('${DASHBOARD_CONFIGMAP_FILE}') not found. Skipping dashboard deployment."
    fi

        # Apply the rds-dashboard.yaml
    if [ -f "rds-dashboard.yaml" ]; then
        kubectl apply -f rds-dashboard.yaml --namespace ${NAMESPACE}
        success "Custom dashboard 'rds-dashboard.yaml' applied successfully."
    else
        warn "Dashboard file 'rds-dashboard.yaml' not found. Skipping."
    fi
}

# --- Main Execution ---
main() {
    if [[ $EUID -eq 0 ]]; then
       warn "This script is running as root. It's recommended to run as a non-root user with sudo privileges."
    fi

    install_prerequisites
    configure_helm_repos
    create_slack_secret
    deploy_monitoring_stack
    deploy_custom_dashboards
    
    info "Deployment process finished."
}

# Run the main function
main
