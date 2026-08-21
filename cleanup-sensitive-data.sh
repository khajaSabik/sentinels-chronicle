#!/bin/bash

echo "========================================"
echo "The Sentinel's Chronicle - Data Cleanup"
echo "========================================"
echo ""
echo "WARNING: This will delete ALL existing chronicles"
echo "and reset style memory to default."
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CHRONICLE_TABLE="sentinels-chronicle-chronicle"
export STYLE_TABLE="sentinels-chronicle-style-memory"
export REGION="us-east-1"

echo ""
echo "1. Backing up current data..."
aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION > chronicle-backup-$(date +%Y%m%d-%H%M%S).json
aws dynamodb get-item --table-name $STYLE_TABLE --key '{"memory_id": {"S": "global"}}' --region $REGION > style-backup-$(date +%Y%m%d-%H%M%S).json

echo "2. Deleting all chronicles..."
# Get all finding IDs
KEYS=$(aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION --attributes-to-get finding_id --query 'Items[*].finding_id.S' --output text)

COUNT=0
for KEY in $KEYS; do
    echo "  Deleting: $KEY"
    aws dynamodb delete-item \
        --table-name $CHRONICLE_TABLE \
        --key "{\"finding_id\": {\"S\": \"$KEY\"}}" \
        --region $REGION > /dev/null
    ((COUNT++))
done

echo "  Deleted $COUNT chronicles"

echo "3. Resetting style memory..."
aws dynamodb put-item \
    --table-name $STYLE_TABLE \
    --item '{
        "memory_id": {"S": "global"},
        "style_notes": {"S": "Measured, atmospheric, security-focused. Never glorify attackers."},
        "updated_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "redacted": {"BOOL": true}
    }' \
    --region $REGION

echo ""
echo "✅ Cleanup complete!"
echo "All sensitive data has been removed."
echo ""
echo "To verify:"
echo "  aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION"
