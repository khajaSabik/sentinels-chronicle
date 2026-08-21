#!/bin/bash

export REGION="us-east-1"
export API_URL=$(aws cloudformation describe-stacks \
    --stack-name sentinels-chronicle \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text)

echo "========================================"
echo "Verifying Data Redaction"
echo "========================================"
echo ""

echo "API URL: $API_URL"

# Test health endpoint
echo "1. Testing Health Endpoint..."
HEALTH_RESPONSE=$(curl -s $API_URL/health)
if [ -z "$HEALTH_RESPONSE" ]; then
    echo "  ❌ Health endpoint returned empty response"
    echo "  Checking Lambda logs..."
    sam logs --stack-name sentinels-chronicle --name SentinelFunction --since 5m
    exit 1
else
    echo "  ✅ Health endpoint working"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool
fi

echo ""
echo "2. Checking Chronicles API..."
CHRONICLES_RESPONSE=$(curl -s $API_URL/chronicles)
if [ -z "$CHRONICLES_RESPONSE" ]; then
    echo "  ❌ Chronicles endpoint returned empty response"
    exit 1
fi

echo "  Checking for sensitive data..."
echo "$CHRONICLES_RESPONSE" | python3 << 'PYEOF'
import sys, json, re

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"  ❌ Invalid JSON response: {e}")
    sys.exit(1)

chronicles = data.get('chronicles', [])
issues = []
found_sensitive = False

for i, c in enumerate(chronicles):
    text = str(c)
    # Check for 12-digit account IDs
    if re.search(r'\b\d{12}\b', text):
        issues.append(f"Item {i}: Found 12-digit account ID")
        found_sensitive = True
    # Check for IP addresses
    if re.search(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', text):
        issues.append(f"Item {i}: Found IP address")
        found_sensitive = True
    # Check for ARNs
    if re.search(r'arn:aws:', text):
        issues.append(f"Item {i}: Found ARN")
        found_sensitive = True
    # Check for instance IDs
    if re.search(r'i-[a-zA-Z0-9]{8,17}', text):
        issues.append(f"Item {i}: Found instance ID")
        found_sensitive = True
    # Check for sensitive keywords
    sensitive_keywords = ['688567278489', 'sentinels-chronicle-688567278489']
    for keyword in sensitive_keywords:
        if keyword in text:
            issues.append(f"Item {i}: Found sensitive keyword: {keyword}")
            found_sensitive = True

if issues:
    print("  ❌ Found sensitive data:")
    for issue in issues:
        print(f"    - {issue}")
else:
    print("  ✅ No sensitive data found in API response")
    
print(f"\n  Total chronicles: {data.get('count', 0)}")
print(f"  Style memory length: {len(data.get('style_memory', ''))}")

# Show first chronicle preview
if chronicles:
    print("\n  Preview of first chronicle:")
    first = chronicles[0]
    print(f"    Title: {first.get('title', 'N/A')}")
    print(f"    Severity: {first.get('severity', 'N/A')}")
    print(f"    Chronicle preview: {first.get('chronicle', 'N/A')[:100]}...")
PYEOF

echo ""
echo "3. Checking DynamoDB directly..."
TABLE_NAME="sentinels-chronicle-chronicle"
COUNT=$(aws dynamodb scan --table-name $TABLE_NAME --region $REGION --select COUNT --query 'Count' --output text)
echo "  Total chronicles in DynamoDB: $COUNT"

if [ "$COUNT" -gt 0 ]; then
    echo "  Sample chronicle:"
    aws dynamodb scan --table-name $TABLE_NAME --region $REGION --limit 1 \
        --query 'Items[0].{Title:title.S, Severity:severity.N, Created:created_at.S}' \
        --output table
fi

echo ""
echo "4. Checking style memory..."
STYLE_MEMORY=$(aws dynamodb get-item \
    --table-name sentinels-chronicle-style-memory \
    --key '{"memory_id": {"S": "global"}}' \
    --region $REGION \
    --query 'Item.style_notes.S' \
    --output text)

if [ -z "$STYLE_MEMORY" ]; then
    echo "  ⚠️ No style memory found"
else
    echo "  ✅ Style memory: ${STYLE_MEMORY:0:100}..."
fi

echo ""
echo "✅ Verification complete!"
