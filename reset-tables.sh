#!/bin/bash

echo "========================================"
echo "The Sentinel's Chronicle - Table Reset"
echo "========================================"
echo ""
echo "This will:"
echo "  1. Delete existing chronicle and style memory tables"
echo "  2. Recreate them with proper schema"
echo "  3. Generate fresh sample findings (with redacted data)"
echo ""
echo "WARNING: ALL EXISTING DATA WILL BE PERMANENTLY DELETED!"
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
echo "1. Deleting existing tables..."

# Delete Chronicle Table
echo "  Deleting $CHRONICLE_TABLE..."
aws dynamodb delete-table \
    --table-name $CHRONICLE_TABLE \
    --region $REGION 2>/dev/null && echo "  ✅ Table deletion initiated" || echo "  ⚠️ Table may not exist"

# Delete Style Memory Table
echo "  Deleting $STYLE_TABLE..."
aws dynamodb delete-table \
    --table-name $STYLE_TABLE \
    --region $REGION 2>/dev/null && echo "  ✅ Table deletion initiated" || echo "  ⚠️ Table may not exist"

echo ""
echo "2. Waiting for tables to be deleted..."
sleep 10

# Wait for tables to be fully deleted
while true; do
    TABLE_STATUS=$(aws dynamodb describe-table --table-name $CHRONICLE_TABLE --region $REGION 2>&1)
    if [[ $TABLE_STATUS == *"ResourceNotFoundException"* ]]; then
        echo "  ✅ Tables deleted successfully"
        break
    fi
    echo "  ⏳ Waiting for tables to be deleted..."
    sleep 5
done

echo ""
echo "3. Recreating Chronicle Table..."
aws dynamodb create-table \
    --table-name $CHRONICLE_TABLE \
    --attribute-definitions AttributeName=finding_id,AttributeType=S \
    --key-schema AttributeName=finding_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

echo ""
echo "4. Recreating Style Memory Table..."
aws dynamodb create-table \
    --table-name $STYLE_TABLE \
    --attribute-definitions AttributeName=memory_id,AttributeType=S \
    --key-schema AttributeName=memory_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

echo ""
echo "5. Waiting for tables to be active..."
sleep 10

# Wait for tables to be active
while true; do
    CHRONICLE_STATUS=$(aws dynamodb describe-table --table-name $CHRONICLE_TABLE --region $REGION --query 'Table.TableStatus' --output text)
    STYLE_STATUS=$(aws dynamodb describe-table --table-name $STYLE_TABLE --region $REGION --query 'Table.TableStatus' --output text)
    
    if [[ "$CHRONICLE_STATUS" == "ACTIVE" && "$STYLE_STATUS" == "ACTIVE" ]]; then
        echo "  ✅ Tables are active"
        break
    fi
    echo "  ⏳ Waiting for tables to become active..."
    sleep 5
done

echo ""
echo "6. Initializing Style Memory..."
aws dynamodb put-item \
    --table-name $STYLE_TABLE \
    --item '{
        "memory_id": {"S": "global"},
        "style_notes": {"S": "Measured, atmospheric, security-focused. Never glorify attackers. The Sentinel tells stories of security events with wisdom and restraint."},
        "updated_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "redacted": {"BOOL": true}
    }' \
    --region $REGION

echo ""
echo "7. Generating Clean Sample Findings..."
export DETECTOR_ID=$(aws guardduty list-detectors --region $REGION --query 'DetectorIds[0]' --output text)

if [ -z "$DETECTOR_ID" ] || [ "$DETECTOR_ID" = "None" ]; then
    echo "  Creating GuardDuty detector..."
    aws guardduty create-detector --enable --region $REGION
    export DETECTOR_ID=$(aws guardduty list-detectors --region $REGION --query 'DetectorIds[0]' --output text)
fi

echo "  Detector ID: $DETECTOR_ID"

# Generate multiple sample findings
echo "  Generating sample findings..."
aws guardduty create-sample-findings \
    --detector-id $DETECTOR_ID \
    --region $REGION

echo "  Waiting for processing..."
sleep 15

echo ""
echo "8. Checking generated data..."
CHRONICLE_COUNT=$(aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION --select COUNT --query 'Count' --output text)
echo "  Chronicles created: $CHRONICLE_COUNT"

if [ "$CHRONICLE_COUNT" -gt 0 ]; then
    echo ""
    echo "✅ Table reset complete!"
    echo ""
    echo "Sample chronicle preview:"
    aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION --limit 1 --query 'Items[0].{Title:title.S, Severity:severity.N, Chronicle:chronicle.S}' --output table
else
    echo ""
    echo "⚠️ No chronicles created yet. Generating more..."
    aws guardduty create-sample-findings --detector-id $DETECTOR_ID --region $REGION
    sleep 10
    
    CHRONICLE_COUNT=$(aws dynamodb scan --table-name $CHRONICLE_TABLE --region $REGION --select COUNT --query 'Count' --output text)
    echo "  Chronicles created: $CHRONICLE_COUNT"
fi

echo ""
echo "📊 Table Information:"
echo "  Chronicle Table: $CHRONICLE_TABLE"
echo "  Style Memory Table: $STYLE_TABLE"
echo "  Total Chronicles: $CHRONICLE_COUNT"

echo ""
echo "🔗 API Endpoints:"
export API_URL=$(aws cloudformation describe-stacks \
    --stack-name sentinels-chronicle \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text)
echo "  API: $API_URL"
echo "  Chronicles: ${API_URL}chronicles"

echo ""
echo "✅ All data has been redacted and reset!"
