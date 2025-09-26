#!/bin/bash

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../../scripts/common.sh" 2>/dev/null || source "$(which tamedia-common)" 2>/dev/null || true

# Handle command line arguments
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    print_version
    exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "tamedia-tunnel - AWS service tunneling tool for Kubernetes"
    echo ""
    echo "Usage: tamedia-tunnel [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "This tool creates secure tunnels to AWS services (DocumentDB, RDS, ElastiCache)"
    echo "and custom endpoints through Kubernetes pods, making them accessible locally."
    exit 0
fi

# Check dependencies
if ! check_dependencies aws jq kubectl; then
    exit 1
fi

# Verify AWS authentication
if ! verify_aws_auth; then
    exit 1
fi

# Verify kubectl context
if ! verify_kubectl_context; then
    exit 1
fi

# Check recommended dependencies
check_recommended_dependencies fzf

# Simplified sanitization - just replace problematic characters
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-*//;s/-*$//' | cut -c1-50
}

# Get AWS identity information
echo "Getting AWS identity..."
AWS_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Unable to get AWS identity. Make sure you're authenticated with AWS."
    exit 1
fi

# Extract session name from UserId for assumed roles
AWS_USER_ID=$(echo "$AWS_IDENTITY" | jq -r '.UserId // empty')
AWS_ACCOUNT=$(echo "$AWS_IDENTITY" | jq -r '.Account // empty')
AWS_ARN=$(echo "$AWS_IDENTITY" | jq -r '.Arn // empty')

if [[ "$AWS_ARN" == *"assumed-role"* ]]; then
    RAW_USER=$(echo "$AWS_USER_ID" | sed 's/.*://')
else
    RAW_USER=$(echo "$AWS_ARN" | sed 's/.*\///')
fi

USER_NAME=$(sanitize_name "$RAW_USER")

echo "AWS Account: ${AWS_ACCOUNT}"
echo "AWS Identity: ${RAW_USER}"
echo ""

# Service selection
if command -v fzf >/dev/null 2>&1; then
    # Use fzf for service selection
    SERVICE_OPTIONS=(
        "1) DocumentDB (MongoDB)"
        "2) RDS PostgreSQL"
        "3) RDS MySQL"
        "4) ElastiCache Redis"
        "5) ElastiCache Valkey"
        "6) Custom (specify your own host/port)"
    )
    
    echo "Select service to tunnel to:"
    SELECTED_SERVICE=$(printf "%s\n" "${SERVICE_OPTIONS[@]}" | fzf --height=40% --layout=reverse --border --prompt="Select service: ")
    
    if [ -z "$SELECTED_SERVICE" ]; then
        print_error "No service selected"
        exit 1
    fi
    
    SERVICE_SELECTION=$(echo "$SELECTED_SERVICE" | cut -d')' -f1)
else
    # Fallback to manual selection if fzf not installed
    echo "Select service to tunnel to:"
    echo "1) DocumentDB (MongoDB)"
    echo "2) RDS PostgreSQL"
    echo "3) RDS MySQL"
    echo "4) ElastiCache Redis"
    echo "5) ElastiCache Valkey"
    echo "6) Custom (specify your own host/port)"
    echo ""
    print_info "Tip: Install 'fzf' for a better selection experience!"
    echo ""
    read -p "Select service number: " SERVICE_SELECTION
fi

case $SERVICE_SELECTION in
    1)
        SERVICE_TYPE="documentdb"
        SERVICE_NAME="DocumentDB"
        DEFAULT_PORT=27017
        ;;
    2)
        SERVICE_TYPE="rds-postgres"
        SERVICE_NAME="RDS PostgreSQL"
        DEFAULT_PORT=5432
        ;;
    3)
        SERVICE_TYPE="rds-mysql"
        SERVICE_NAME="RDS MySQL"
        DEFAULT_PORT=3306
        ;;
    4)
        SERVICE_TYPE="elasticache-redis"
        SERVICE_NAME="ElastiCache Redis"
        DEFAULT_PORT=6379
        ;;
    5)
        SERVICE_TYPE="elasticache-valkey"
        SERVICE_NAME="ElastiCache Valkey"
        DEFAULT_PORT=6379
        ;;
    6)
        SERVICE_TYPE="custom"
        SERVICE_NAME="Custom Service"
        echo ""
        read -p "Enter hostname/endpoint: " CUSTOM_HOST
        if [ -z "$CUSTOM_HOST" ]; then
            print_error "Hostname cannot be empty"
            exit 1
        fi
        
        read -p "Enter port [default: 8080]: " CUSTOM_PORT
        DEFAULT_PORT=${CUSTOM_PORT:-8080}
        
        if ! [[ "$DEFAULT_PORT" =~ ^[0-9]+$ ]] || [ "$DEFAULT_PORT" -lt 1 ] || [ "$DEFAULT_PORT" -gt 65535 ]; then
            print_error "Port must be a number between 1 and 65535"
            exit 1
        fi
        
        # Set the instance info for custom service
        INSTANCE_ID="custom-$(echo "$CUSTOM_HOST" | tr '.' '-')"
        INSTANCE_ENDPOINT="$CUSTOM_HOST"
        SECRET_FILTER="custom"
        
        echo ""
        echo "Custom service configured:"
        echo "  Host: $CUSTOM_HOST"
        echo "  Port: $DEFAULT_PORT"
        echo ""
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo "Selected: $SERVICE_NAME"
echo ""

# Skip AWS instance fetching for custom services
if [ "$SERVICE_TYPE" = "custom" ]; then
    # Custom service already has INSTANCE_ID and INSTANCE_ENDPOINT set
    echo "Using custom endpoint: $INSTANCE_ENDPOINT:$DEFAULT_PORT"
else
    # Fetch instances based on service type
    echo "Fetching $SERVICE_NAME instances..."

    # Store stderr to check for permission errors
    TEMP_ERROR=$(mktemp)

    case $SERVICE_TYPE in
    "documentdb")
        INSTANCES=$(aws docdb describe-db-clusters --query 'DBClusters[?Status==`available`].[DBClusterIdentifier,Endpoint]' --output text 2>"$TEMP_ERROR")
        AWS_EXIT_CODE=$?
        SECRET_FILTER="docdb\|documentdb"
        ;;
    "rds-postgres")
        INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available` && Engine==`postgres`].[DBInstanceIdentifier,Endpoint.Address]' --output text 2>"$TEMP_ERROR")
        AWS_EXIT_CODE=$?
        SECRET_FILTER="postgres\|rds"
        ;;
    "rds-mysql")
        INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available` && (Engine==`mysql` || Engine==`mariadb`)].[DBInstanceIdentifier,Endpoint.Address]' --output text 2>"$TEMP_ERROR")
        AWS_EXIT_CODE=$?
        SECRET_FILTER="mysql\|mariadb\|rds"
        ;;
    "elasticache-redis")
        INSTANCES=$(aws elasticache describe-cache-clusters --query 'CacheClusters[?CacheClusterStatus==`available` && Engine==`redis`].[CacheClusterId,RedisConfiguration.PrimaryEndpoint.Address // CacheNodes[0].Endpoint.Address]' --output text 2>"$TEMP_ERROR")
        AWS_EXIT_CODE=$?
        SECRET_FILTER="redis\|elasticache"
        ;;
    "elasticache-valkey")
        INSTANCES=$(aws elasticache describe-cache-clusters --query 'CacheClusters[?CacheClusterStatus==`available` && Engine==`valkey`].[CacheClusterId,RedisConfiguration.PrimaryEndpoint.Address // CacheNodes[0].Endpoint.Address]' --output text 2>"$TEMP_ERROR")
        AWS_EXIT_CODE=$?
        SECRET_FILTER="valkey\|elasticache"
        ;;
esac

    # Check for errors
    if [ $AWS_EXIT_CODE -ne 0 ]; then
        ERROR_MSG=$(cat "$TEMP_ERROR")
        rm -f "$TEMP_ERROR"
        
        if echo "$ERROR_MSG" | grep -q "UnauthorizedException\|AccessDenied\|is not authorized to perform"; then
            print_error "Insufficient AWS permissions to list $SERVICE_NAME instances."
            print_info "Required permission: $(echo "$ERROR_MSG" | grep -o '[a-z]*:[A-Za-z]*' | head -1 || echo "Check AWS IAM permissions")"
        else
            print_error "Failed to fetch $SERVICE_NAME instances: ${ERROR_MSG}"
        fi
        exit 1
    fi

    rm -f "$TEMP_ERROR"

    # Check if no instances found
    if [ -z "$INSTANCES" ]; then
        print_warning "No available $SERVICE_NAME instances found in this AWS account/region."
        print_info "Make sure you:"
        print_info "  - Are in the correct AWS region"
        print_info "  - Have $SERVICE_NAME instances in 'available' state"
        print_info "  - Have the correct AWS profile/credentials configured"
        exit 1
    fi

    # Display instances for selection
    echo "Available $SERVICE_NAME instances:"
    
    if command -v fzf >/dev/null 2>&1; then
        # Use fzf for instance selection
        SELECTED_LINE=$(echo "$INSTANCES" | fzf --height=40% --layout=reverse --border --prompt="Select instance: ")
        
        if [ -z "$SELECTED_LINE" ]; then
            print_error "No instance selected"
            exit 1
        fi
        
        INSTANCE_ID=$(echo "$SELECTED_LINE" | awk '{print $1}')
        INSTANCE_ENDPOINT=$(echo "$SELECTED_LINE" | awk '{print $2}')
    else
        # Fallback to manual selection
        echo "$INSTANCES" | nl -w2 -s') '
        
        # Get user selection
        echo ""
        read -p "Select instance number: " SELECTION
        
        if ! [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
            echo "Error: Please enter a valid number"
            exit 1
        fi
        
        # Extract selected instance info
        SELECTED_LINE=$(echo "$INSTANCES" | sed -n "${SELECTION}p")
        if [ -z "$SELECTED_LINE" ]; then
            echo "Error: Invalid selection"
            exit 1
        fi
        
        INSTANCE_ID=$(echo "$SELECTED_LINE" | awk '{print $1}')
        INSTANCE_ENDPOINT=$(echo "$SELECTED_LINE" | awk '{print $2}')
    fi

    echo ""
    echo "Selected instance: $INSTANCE_ID"
    echo "Endpoint: $INSTANCE_ENDPOINT"
    echo ""
fi

# Look for related secrets
echo "Searching for secrets..."

# First try to find secrets with instance ID or service filter
FILTERED_SECRETS=$(aws secretsmanager list-secrets --query "SecretList[?contains(Name, \`${INSTANCE_ID}\`) || contains(Name, \`${SECRET_FILTER}\`)].Name" --output text 2>/dev/null)

SECRET_NAME=""

# Check if fzf is available
if command -v fzf >/dev/null 2>&1; then
    echo "Select a secret (or press ESC to skip):"
    
    # Get all secrets if no filtered results or offer to search all
    if [ -z "$FILTERED_SECRETS" ]; then
        echo "No secrets found matching filters. Searching all secrets..."
        ALL_SECRETS=$(aws secretsmanager list-secrets --query "SecretList[].Name" --output text 2>/dev/null | tr '\t' '\n')
        SECRET_NAME=$(echo "$ALL_SECRETS" | fzf --prompt="Select secret: " --height=40% --layout=reverse --border)
    else
        # Show filtered secrets first, but allow searching all
        echo "Found $(echo "$FILTERED_SECRETS" | wc -w) matching secret(s). Press TAB to search all secrets."
        FILTERED_LIST=$(echo "$FILTERED_SECRETS" | tr '\t' '\n')
        
        # Create a combined list with a separator
        SECRET_NAME=$(printf "%s\n---SEARCH ALL SECRETS---\n" "$FILTERED_LIST" | \
            fzf --prompt="Select secret: " --height=40% --layout=reverse --border | \
            grep -v "^---SEARCH ALL SECRETS---$" || true)
        
        # If user selected the separator, show all secrets
        if [ -z "$SECRET_NAME" ] && [ $? -eq 0 ]; then
            ALL_SECRETS=$(aws secretsmanager list-secrets --query "SecretList[].Name" --output text 2>/dev/null | tr '\t' '\n')
            SECRET_NAME=$(echo "$ALL_SECRETS" | fzf --prompt="Select secret (all): " --height=40% --layout=reverse --border)
        fi
    fi
    
    if [ -n "$SECRET_NAME" ]; then
        echo "Selected secret: $SECRET_NAME"
    else
        echo "No secret selected"
    fi
else
    # Fallback to original numbered selection if fzf not available
    if [ -n "$FILTERED_SECRETS" ]; then
        echo "Found potential secrets:"
        echo "$FILTERED_SECRETS" | tr '\t' '\n' | nl -w2 -s') '
        echo "$(($(echo "$FILTERED_SECRETS" | wc -w) + 1))) Skip secret selection"
        echo ""
        read -p "Select secret number (or skip): " SECRET_SELECTION
        
        if [[ "$SECRET_SELECTION" =~ ^[0-9]+$ ]] && [ "$SECRET_SELECTION" -le "$(echo "$FILTERED_SECRETS" | wc -w)" ]; then
            SECRET_NAME=$(echo "$FILTERED_SECRETS" | tr '\t' '\n' | sed -n "${SECRET_SELECTION}p")
            echo "Selected secret: $SECRET_NAME"
        else
            echo "Skipping secret selection"
        fi
    else
        echo "No $SERVICE_NAME secrets found. Install 'fzf' to search all secrets interactively."
        read -p "Do you want to list all secrets? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ALL_SECRETS=$(aws secretsmanager list-secrets --query "SecretList[].Name" --output text 2>/dev/null)
            if [ -n "$ALL_SECRETS" ]; then
                echo "All available secrets:"
                echo "$ALL_SECRETS" | tr '\t' '\n' | nl -w2 -s') '
                echo "$(($(echo "$ALL_SECRETS" | wc -w) + 1))) Skip secret selection"
                echo ""
                read -p "Select secret number (or skip): " SECRET_SELECTION
                
                if [[ "$SECRET_SELECTION" =~ ^[0-9]+$ ]] && [ "$SECRET_SELECTION" -le "$(echo "$ALL_SECRETS" | wc -w)" ]; then
                    SECRET_NAME=$(echo "$ALL_SECRETS" | tr '\t' '\n' | sed -n "${SECRET_SELECTION}p")
                    echo "Selected secret: $SECRET_NAME"
                else
                    echo "Skipping secret selection"
                fi
            fi
        fi
    fi
fi
echo ""

# Create tunnel pod
TIMESTAMP=$(date +%s)
POD_NAME="${SERVICE_TYPE}-tunnel-${USER_NAME}-${TIMESTAMP}"

echo "Creating tunnel pod: ${POD_NAME}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: tunnels
  labels:
    created-by: ${USER_NAME}
    service: ${SERVICE_TYPE}
    instance: ${INSTANCE_ID}
  annotations:
    tunnel.created-at: "$(date -Iseconds)"
    tunnel.target: "${INSTANCE_ENDPOINT}"
    aws-user: "${RAW_USER}"
    aws-account: "${AWS_ACCOUNT}"
    instance-id: "${INSTANCE_ID}"
    service-type: "${SERVICE_TYPE}"
spec:
  restartPolicy: Never
  containers:
  - name: socat-tunnel
    image: alpine/socat
    args:
    - tcp-listen:${DEFAULT_PORT},fork,reuseaddr
    - tcp-connect:${INSTANCE_ENDPOINT}:${DEFAULT_PORT}
EOF

if [ $? -eq 0 ]; then
    echo "Pod created successfully!"
    echo "Waiting for pod to be ready..."
    kubectl wait --for=condition=Ready pod/${POD_NAME} -n tunnels --timeout=60s
    
    if [ $? -eq 0 ]; then
        # Find available local port
        LOCAL_PORT=$DEFAULT_PORT
        while netstat -an 2>/dev/null | grep -q ":${LOCAL_PORT} "; do
            LOCAL_PORT=$((LOCAL_PORT + 1))
        done
        
        echo ""
        echo "=== CONNECTION INFO ==="
        echo "Service: $SERVICE_NAME"
        echo "Instance: $INSTANCE_ID"
        echo "Local port: $LOCAL_PORT"
        
        # Generate connection commands based on service type
        if [ -n "$SECRET_NAME" ]; then
            echo "Getting credentials from secret: $SECRET_NAME"
            SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query SecretString --output text 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$SECRET_VALUE" ]; then
                USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username // empty')
                PASSWORD=$(echo "$SECRET_VALUE" | jq -r '.password // empty')
                DATABASE=$(echo "$SECRET_VALUE" | jq -r '.database // .dbname // empty')
                
                if [ -n "$USERNAME" ]; then
                    echo ""
                    echo "Ready to connect! Copy and paste:"
                    
                    case $SERVICE_TYPE in
                        "documentdb")
                            if [ -n "$DATABASE" ]; then
                                echo "mongosh \"mongodb://localhost:${LOCAL_PORT}/${DATABASE}?retryWrites=false&authMechanism=SCRAM-SHA-1\" --username ${USERNAME} --password \"\$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password')\""
                            else
                                echo "mongosh \"mongodb://localhost:${LOCAL_PORT}?retryWrites=false&authMechanism=SCRAM-SHA-1\" --username ${USERNAME} --password \"\$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password')\""
                            fi
                            ;;
                        "rds-postgres")
                            echo "psql \"postgresql://${USERNAME}:\$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password')@localhost:${LOCAL_PORT}/${DATABASE:-postgres}\""
                            ;;
                        "rds-mysql")
                            echo "mysql -h localhost -P ${LOCAL_PORT} -u ${USERNAME} -p\"\$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password')\" ${DATABASE}"
                            ;;
                        "elasticache-redis"|"elasticache-valkey")
                            echo "redis-cli -h localhost -p ${LOCAL_PORT}"
                            if [ -n "$PASSWORD" ]; then
                                echo "Then run: AUTH \"\$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password // .auth_token')\""
                            fi
                            ;;
                        "custom")
                            echo "# Connect to your custom service:"
                            echo "# Host: localhost:${LOCAL_PORT} (tunneled from ${INSTANCE_ENDPOINT}:${DEFAULT_PORT})"
                            if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
                                echo "# Username: ${USERNAME}"
                                echo "# Password: \$(aws secretsmanager get-secret-value --secret-id '${SECRET_NAME}' --query SecretString --output text | jq -r '.password')"
                            fi
                            ;;
                    esac
                else
                    show_manual_connection
                fi
            else
                show_manual_connection
            fi
        else
            show_manual_connection
        fi
        
        echo ""
        echo "=== CLEANUP ==="
        echo "Delete this tunnel:"
        echo "kubectl delete pod ${POD_NAME} -n tunnels"
        echo ""
        echo "Delete all your tunnels:"
        echo "kubectl delete pods -n tunnels -l created-by=${USER_NAME}"
        echo ""
        echo "Press Ctrl+C to stop port forwarding"
        echo ""
        
        # Set up cleanup prompt on exit
        cleanup() {
            echo ""
            echo "Port forwarding stopped."
            
            if command -v fzf >/dev/null 2>&1; then
                # Use fzf for cleanup decision
                CLEANUP_CHOICE=$(echo -e "Yes - Delete tunnel pod\nNo - Keep pod running" | fzf --height=20% --layout=reverse --border --prompt="Delete tunnel pod ${POD_NAME}? ")
                
                if [[ "$CLEANUP_CHOICE" == "Yes"* ]]; then
                    kubectl delete pod ${POD_NAME} -n tunnels
                    echo "Tunnel pod deleted"
                else
                    echo "Tunnel pod kept running"
                    echo "Delete later with: kubectl delete pod ${POD_NAME} -n tunnels"
                fi
            else
                # Fallback to manual prompt
                read -p "Delete tunnel pod ${POD_NAME}? (Y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    echo "Tunnel pod kept running"
                    echo "Delete later with: kubectl delete pod ${POD_NAME} -n tunnels"
                else
                    kubectl delete pod ${POD_NAME} -n tunnels
                    echo "Tunnel pod deleted"
                fi
            fi
        }
        
        # Set trap for cleanup on script exit
        trap cleanup EXIT
        
        # Start port forwarding
        kubectl port-forward -n tunnels ${POD_NAME} ${LOCAL_PORT}:${DEFAULT_PORT}
    else
        echo "Pod failed to become ready. Check with:"
        echo "kubectl describe pod ${POD_NAME} -n tunnels"
        echo "kubectl logs ${POD_NAME} -n tunnels"
    fi
else
    echo "Failed to create pod"
fi

# Function to show manual connection examples
show_manual_connection() {
    echo ""
    echo "Manual connection examples:"
    case $SERVICE_TYPE in
        "documentdb")
            echo "mongosh \"mongodb://localhost:${LOCAL_PORT}?retryWrites=false&authMechanism=SCRAM-SHA-1\" --username <username> --password <password>"
            ;;
        "rds-postgres")
            echo "psql \"postgresql://<username>:<password>@localhost:${LOCAL_PORT}/<database>\""
            ;;
        "rds-mysql")
            echo "mysql -h localhost -P ${LOCAL_PORT} -u <username> -p<password> <database>"
            ;;
        "elasticache-redis"|"elasticache-valkey")
            echo "redis-cli -h localhost -p ${LOCAL_PORT}"
            echo "Then run: AUTH <password>  # if authentication is enabled"
            ;;
        "custom")
            echo "# Custom service connection:"
            echo "# Connect to: localhost:${LOCAL_PORT}"
            echo "# This tunnels to: ${INSTANCE_ENDPOINT}:${DEFAULT_PORT}"
            echo "# Use your application-specific client to connect"
            ;;
    esac
}