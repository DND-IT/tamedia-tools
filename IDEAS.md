# AWS-K8s Tools Collection

## **Core Tools**

### 1. **aws-tunnel** (Current tool)
- Multi-service tunneling (DocumentDB, RDS, Redis, etc.)
- Automatic secret integration
- Smart port management

### 2. **aws-secrets**
- List/search secrets by service
- Secure secret retrieval with formatting
- Bulk secret operations
- Secret rotation helpers

### 3. **aws-logs**
- Stream CloudWatch logs to terminal
- Multi-log group aggregation
- Real-time log filtering
- Export logs to files

### 4. **k8s-cleanup**
- Clean up orphaned tunnel pods
- Resource usage reporting
- Batch deletion by user/labels
- Age-based cleanup

### 5. **aws-profile**
- Switch between AWS profiles/roles
- Show current AWS context
- Profile validation
- Multi-account helpers

## **Advanced Tools**

### 6. **k8s-exec**
- Smart pod selection for exec
- Session recording
- Multi-pod exec
- Container auto-detection

### 7. **aws-resources**
- Cross-service resource discovery
- Cost analysis helpers
- Resource tagging utilities
- Inventory generation

### 8. **k8s-port-manager**
- Manage multiple port forwards
- Port conflict resolution
- Session persistence
- Background process management

### 9. **aws-iam-helper**
- Role assumption utilities
- Permission testing
- Policy simulation
- Access key rotation

### 10. **k8s-debug**
- Network troubleshooting pods
- DNS resolution testing
- Connectivity checking
- Performance testing
