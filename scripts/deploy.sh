#!/bin/bash

# Portfolio Dashboard Deployment Script
# This script deploys your Flask application to AWS using Terraform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${2}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_message "🚀 Starting Portfolio Dashboard Deployment" $BLUE

# Check if required tools are installed
check_requirements() {
    print_message "Checking requirements..." $YELLOW
    
    if ! command -v terraform &> /dev/null; then
        print_message "❌ Terraform is not installed. Please install it first." $RED