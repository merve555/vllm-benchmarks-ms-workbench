#!/bin/bash

# vLLM Benchmark Infrastructure Cleanup Script
# This script removes all infrastructure created by Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    if ! command_exists gcloud; then
        print_error "Google Cloud CLI is not installed"
        exit 1
    fi
    
    print_success "All prerequisites are available"
}

# Confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will destroy all infrastructure created by Terraform:"
    echo "  - TPU GKE cluster (and all Kubernetes resources)"
    echo "  - GPU GKE cluster (and all Kubernetes resources)"
    echo "  - GCS bucket and all data"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
}

# Destroy Terraform infrastructure
destroy_infrastructure() {
    print_status "Destroying Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Check if there are resources to destroy
    if ! terraform state list >/dev/null 2>&1; then
        print_warning "No Terraform state found. Nothing to destroy."
        return 0
    fi
    
    # Destroy infrastructure
    print_warning "Running terraform destroy..."
    print_status "This will destroy all GKE clusters and the GCS bucket."
    print_status "All Kubernetes resources will be automatically deleted."
    
    terraform destroy -auto-approve
    
    cd "$SCRIPT_DIR"
    print_success "Infrastructure destroyed"
}

# Cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove logs directory
    if [ -d "$SCRIPT_DIR/../logs" ]; then
        rm -rf "$SCRIPT_DIR/../logs"
        print_status "Removed logs directory"
    fi
    
    # Remove terraform plan file
    if [ -f "$TERRAFORM_DIR/tfplan" ]; then
        rm -f "$TERRAFORM_DIR/tfplan"
        print_status "Removed terraform plan file"
    fi
    
    # Remove terraform state backup files
    if [ -f "$TERRAFORM_DIR/terraform.tfstate.backup" ]; then
        rm -f "$TERRAFORM_DIR/terraform.tfstate.backup"
        print_status "Removed terraform state backup"
    fi
    
    print_success "Local files cleaned up"
}

# Main execution
main() {
    print_status "Starting vLLM benchmark infrastructure cleanup..."
    
    # Check prerequisites
    check_prerequisites
    
    # Confirm cleanup
    confirm_cleanup
    
    # Destroy Terraform infrastructure (this will also clean up all K8s resources)
    destroy_infrastructure
    
    # Cleanup local files
    cleanup_local_files
    
    echo ""
    print_success "Cleanup completed successfully!"
    print_status "All infrastructure has been removed"
    print_status "All Kubernetes resources have been automatically deleted"
}

# Run main function
main "$@"
