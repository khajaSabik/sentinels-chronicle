#!/bin/bash

echo "========================================"
echo "Sentinel's Chronicle - Status Check"
echo "========================================"

API_URL="https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/"
DETECTOR_ID=$(aws guardduty list-detectors --region us-east-1 --query 'DetectorIds[0]' --output text)

echo "1. GuardDuty Detector: $DETECTOR_ID"

echo "2. Lambda Function:"
aws lambda get-function-configuration \
    --function-name sentinels-chronicle-SentinelFunction-yWsgXo9z73w9 \
    --region us-east-1 \
    --query '{State:State, LastUpdateStatus:LastUpdateStatus}' \
    --output table

echo "3. API Health:"
curl -s $API_URL/health | python3 -m json.tool

echo "4. Chronicles Count:"
curl -s $API_URL/chronicles | python3 -c "import sys, json; print(f'Count: {json.load(sys.stdin).get(\"count\", 0)}')"

echo "5. Generating new sample findings..."
aws guardduty create-sample-findings --detector-id $DETECTOR_ID --region us-east-1

echo "6. Waiting 20 seconds..."
sleep 20

echo "7. Updated Chronicles Count:"
curl -s $API_URL/chronicles | python3 -c "import sys, json; print(f'Count: {json.load(sys.stdin).get(\"count\", 0)}')"

echo "========================================"
