import json
import os
import re
from datetime import datetime, timezone
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
bedrock = boto3.client("bedrock-runtime")

CHRONICLE_TABLE_NAME = os.environ.get("CHRONICLE_TABLE", "sentinels-chronicle-chronicle")
STYLE_MEMORY_TABLE_NAME = os.environ.get("STYLE_MEMORY_TABLE", "sentinels-chronicle-style-memory")
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")

chronicle = dynamodb.Table(CHRONICLE_TABLE_NAME)
memory = dynamodb.Table(STYLE_MEMORY_TABLE_NAME)


def _safe_text(value, limit=1800):
    if value is None:
        return ""
    return str(value).replace("\x00", " ")[:limit]


def _aggressive_redact(text):
    """Most aggressive redaction - removes ANY pattern that looks sensitive"""
    if not text:
        return text
    
    # Start with the raw text
    redacted = str(text)
    
    # 1. Remove ALL 12-digit numbers (account IDs)
    redacted = re.sub(r'\b\d{12}\b', '[ACCOUNT]', redacted)
    
    # 2. Remove ALL IP addresses
    redacted = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP]', redacted)
    
    # 3. Remove ALL ARNs (any format)
    redacted = re.sub(r'arn:aws:[a-zA-Z0-9-]+:[a-zA-Z0-9-]*:[0-9]+:[a-zA-Z0-9-/]+', '[ARN]', redacted)
    
    # 4. Remove ALL i-* instance IDs
    redacted = re.sub(r'i-[a-zA-Z0-9]{8,}', '[INSTANCE]', redacted)
    redacted = re.sub(r'i-[a-zA-Z0-9]{8,17}', '[INSTANCE]', redacted)
    
    # 5. Remove ALL sg-* security groups
    redacted = re.sub(r'sg-[a-zA-Z0-9]{8,}', '[SG]', redacted)
    
    # 6. Remove ALL vpc-* IDs
    redacted = re.sub(r'vpc-[a-zA-Z0-9]{8,}', '[VPC]', redacted)
    
    # 7. Remove ALL subnet-* IDs
    redacted = re.sub(r'subnet-[a-zA-Z0-9]{8,}', '[SUBNET]', redacted)
    
    # 8. Remove ALL s3 bucket names with account IDs
    redacted = re.sub(r'sentinels-chronicle-\d+', '[BUCKET]', redacted)
    redacted = re.sub(r's3://[a-z0-9.-]+', '[BUCKET]', redacted)
    
    # 9. Remove ALL domain names (AWS)
    redacted = re.sub(r'[a-z0-9.-]+\.(s3|cloudfront|execute-api|amazonaws)\.(com|net|org)', '[DOMAIN]', redacted)
    
    # 10. Remove ALL API Gateway IDs (10 char alphanumeric)
    redacted = re.sub(r'\b[a-zA-Z0-9]{10}\b(?=.*\.execute-api)', '[API]', redacted)
    
    # 11. Remove ALL CloudFront distribution IDs
    redacted = re.sub(r'\bE[A-Z0-9]{13,}', '[DIST]', redacted)
    
    # 12. Remove ALL UUIDs
    redacted = re.sub(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[UUID]', redacted)
    
    # 13. Remove ALL hex strings (32 chars)
    redacted = re.sub(r'\b[a-fA-F0-9]{32}\b', '[HEX]', redacted)
    
    # 14. Remove ANYTHING that looks like "arn"
    redacted = re.sub(r'\barn\b', '[ARN]', redacted, flags=re.IGNORECASE)
    
    # 15. Remove ANY mention of account
    redacted = re.sub(r'\baccount\s+\d{5,}\b', 'account', redacted, flags=re.IGNORECASE)
    
    return redacted


def get_style_memory():
    try:
        response = memory.get_item(Key={"memory_id": "global"})
        style = response.get("Item", {}).get(
            "style_notes",
            "Measured, atmospheric, security-focused. Never glorify attackers."
        )
        return _aggressive_redact(style)
    except Exception as e:
        print(f"Error getting style memory: {e}")
        return "Measured, atmospheric, security-focused. Never glorify attackers."


def generate_chronicle(finding, style_notes):
    severity = float(finding.get("severity", 0))
    finding_type = _aggressive_redact(_safe_text(finding.get("type"), 300))
    title = _aggressive_redact(_safe_text(finding.get("title"), 300))
    description = _aggressive_redact(_safe_text(finding.get("description"), 1800))
    region = _aggressive_redact(_safe_text(finding.get("region"), 100))
    safe_style_notes = _aggressive_redact(style_notes)

    prompt = f"""
You are The Sentinel's Chronicle, a security storyteller.

Turn the SECURITY EVENT DATA below into a short cautionary chronicle.

ABSOLUTELY CRITICAL RULES - YOU MUST FOLLOW:
- NEVER, EVER include any AWS Account IDs (12-digit numbers)
- NEVER include any IP addresses (like 192.168.1.1)
- NEVER include any ARNs (arn:aws:*)
- NEVER include any Instance IDs (i-*)
- NEVER include any Security Group IDs (sg-*)
- NEVER include any VPC IDs (vpc-*)
- NEVER include any technical identifiers at all
- Use ONLY general terms like "a resource", "an instance", "the account"
- Do NOT use specific numbers or IDs anywhere
- Severity 0-3: quiet warning
- Severity 4-6.9: tense watch-report  
- Severity 7-10: urgent, dark chronicle
- End with one short "Sentinel's lesson"
- 180-280 words
- Use a descriptive title

EVOLVING STYLE MEMORY:
{safe_style_notes}

SECURITY EVENT DATA (already redacted):
Severity: {severity}
Finding type: {finding_type}
Title: {title}
Description: {description}
Region: {region}
"""

    try:
        response = bedrock.converse(
            modelId=MODEL_ID,
            system=[{
                "text": """You write concise, factual security parables. 
                CRITICAL INSTRUCTION: NEVER output AWS Account IDs, IP addresses, 
                ARNs, Instance IDs (i-*), or ANY technical identifiers. 
                Use only general terms like 'the account' or 'a resource'.
                If you don't know a detail, make it generic.
                NEVER use numbers that look like account IDs (12 digits)."""
            }],
            messages=[{
                "role": "user",
                "content": [{"text": prompt}]
            }],
            inferenceConfig={
                "maxTokens": 700,
                "temperature": 0.7,
                "topP": 0.9,
            },
        )
        chronicle_text = response["output"]["message"]["content"][0]["text"].strip()
        # Triple redaction pass
        chronicle_text = _aggressive_redact(chronicle_text)
        chronicle_text = _aggressive_redact(chronicle_text)
        return _aggressive_redact(chronicle_text)
    except Exception as e:
        print(f"Error generating chronicle: {e}")
        return f"A security event of severity {severity} was observed."


def update_style_memory(previous, severity):
    tone = (
        "more restrained and precise for repeated low-severity findings"
        if severity < 4
        else "more tense and concise when the threat is significant"
    )
    new_memory = f"{previous}; current lesson: {tone}. Avoid repetition."
    return _aggressive_redact(new_memory)


def handle_guardduty_event(event):
    detail = event.get("detail", {})
    finding_id = detail.get("id") or event.get("id")

    if not finding_id:
        return {"error": "Missing finding ID"}

    existing = chronicle.get_item(Key={"finding_id": finding_id}).get("Item")
    if existing:
        return {"status": "duplicate"}

    style_notes = get_style_memory()
    severity = Decimal(str(detail.get("severity", 0)))
    chronicle_text = generate_chronicle(detail, style_notes)

    now = datetime.now(timezone.utc).isoformat()

    chronicle.put_item(Item={
        "finding_id": finding_id,
        "created_at": now,
        "severity": severity,
        "finding_type": _aggressive_redact(_safe_text(detail.get("type"), 300)),
        "title": _aggressive_redact(_safe_text(detail.get("title"), 300)),
        "region": _aggressive_redact(_safe_text(event.get("region"), 100)),
        "chronicle": chronicle_text,
        "redacted": True
    })

    new_memory = update_style_memory(style_notes, float(severity))
    memory.put_item(Item={
        "memory_id": "global",
        "style_notes": new_memory[-1800:],
        "updated_at": now,
        "redacted": True
    })

    return {"status": "created"}


def handle_api_request(event):
    path = event.get("path", "")
    http_method = event.get("httpMethod", "GET")
    
    if path == "/health":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()})
        }
    
    if path == "/chronicles" and http_method == "GET":
        try:
            response = chronicle.scan()
            items = response.get("Items", [])
            
            chronicles = []
            for item in items:
                chronicles.append({
                    "finding_id": "[REDACTED]",
                    "created_at": item.get("created_at", ""),
                    "severity": float(item.get("severity", 0)),
                    "finding_type": _aggressive_redact(item.get("finding_type", "")),
                    "title": _aggressive_redact(item.get("title", "")),
                    "region": _aggressive_redact(item.get("region", "")),
                    "chronicle": _aggressive_redact(item.get("chronicle", ""))
                })
            
            chronicles.sort(key=lambda x: x.get("created_at", ""), reverse=True)
            style_memory = get_style_memory()
            
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
                "body": json.dumps({
                    "chronicles": chronicles,
                    "style_memory": style_memory,
                    "count": len(chronicles)
                })
            }
        except Exception as e:
            print(f"Error: {e}")
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"error": str(e)})
            }
    
    return {
        "statusCode": 404,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps({"error": f"Not found: {path}"})
    }


def handler(event, context):
    try:
        if event.get("httpMethod"):
            return handle_api_request(event)
        
        if event.get("source") == "aws.guardduty" or event.get("detail-type") == "GuardDuty Finding":
            return handle_guardduty_event(event)
        
        if event.get("rawPath"):
            return handle_api_request({"path": event.get("rawPath", ""), "httpMethod": "GET"})
        
        return {"statusCode": 200, "body": json.dumps({"message": "Event received"})}
    except Exception as e:
        print(f"Error: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
