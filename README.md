# 🗡️ The Sentinel's Chronicle

**An event-driven creative security agent that transforms Amazon GuardDuty findings into evolving narrative chronicles using Amazon Bedrock (Nova Lite).**

[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![Lambda](https://img.shields.io/badge/AWS_Lambda-FF9900?style=for-the-badge&logo=aws-lambda&logoColor=white)](https://aws.amazon.com/lambda/)
[![Bedrock](https://img.shields.io/badge/Amazon_Bedrock-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/bedrock/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> **NOTE:** Replace every `YOUR_USERNAME` placeholder in this file with your real GitHub username before publishing.

---

## 📖 Vision

Unlike scheduled creative agents that wake up every morning whether or
not anything happened, **the Sentinel wakes up only when something
real occurs.** It listens directly to Amazon GuardDuty security
findings and transforms each one into an evolving narrative chronicle
— readable, memorable context in place of a raw JSON alert.

> *"The Sentinel's Chronicle is an autonomous creative security agent that listens to real AWS GuardDuty events and transforms security findings into an evolving narrative archive."*

---

## 🏗️ Architecture

```
Amazon GuardDuty
      │  finding detected
      ▼
Amazon EventBridge
      │
      ▼
AWS Lambda ──────────────► Amazon DynamoDB
      │                     (chronicles + style memory)
      ▼
Amazon Bedrock (Nova Lite)
      │  generates chronicle
      ▼
Amazon API Gateway  (/chronicles, /health)
      │
      ▼
Amazon CloudFront (HTTPS + OAI)
      │
      ▼
Amazon S3  (private static site — no public bucket access)
```

**Flow, step by step:** GuardDuty → EventBridge → Lambda → Bedrock
Nova Lite → DynamoDB → API Gateway → CloudFront → S3 (private, OAI-only).

---

## ✨ Features

| Feature | Description |
|:---|:---|
| ⚡ **Event-driven** | Responds to real GuardDuty security findings in real time — no polling, no schedule |
| 🤖 **AI-powered** | Amazon Bedrock Nova Lite generates each chronicle's narrative |
| 🧠 **Evolving memory** | Style memory in DynamoDB refines the Sentinel's voice over time |
| 🔒 **Security-hardened** | All sensitive data (account IDs, IPs, ARNs, etc.) redacted before storage or display |
| 🌐 **Full-stack** | Lambda + DynamoDB + API Gateway + S3 + CloudFront |
| 📦 **Infrastructure as code** | Single AWS SAM template for repeatable deployment |
| 🎨 **Dark-themed UI** | Responsive web interface styled as a clinical/watch-keeper's journal |
| 🔄 **Idempotent** | Handles duplicate GuardDuty events gracefully |

---

## 🚀 Live Demo

| Resource | URL |
|:---|:---|
| 🌐 **Website** | https://sentinels-chronicle-688567278489.s3-website-us-east-1.amazonaws.com |
| 🔗 **API base** | https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/ |
| 📊 **Health check** | https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/health |
| 📝 **Chronicles feed** | https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/chronicles |

### Sample API response

```json
{
  "chronicles": [
    {
      "finding_id": "[REDACTED]",
      "created_at": "2026-08-21T21:37:40.704115+00:00",
      "severity": 8.0,
      "finding_type": "CryptoCurrency:Runtime/BitcoinTool.B!DNS",
      "title": "A Bitcoin-related domain name was queried by EC2 instance [INSTANCE].",
      "region": "us-east-1",
      "chronicle": "### The Shadow of Crypto: A Bitcoin Domain Query..."
    }
  ],
  "style_memory": "Measured, atmospheric, security-focused.",
  "count": 409
}
```

---

## 🛠️ AWS services used

| Service | Purpose |
|---|---|
| **Amazon GuardDuty** | Security event source that detects real threats |
| **Amazon EventBridge** | Routes GuardDuty findings to Lambda |
| **AWS Lambda** | Executes the agent's core logic |
| **Amazon Bedrock (Nova Lite)** | Generates each chronicle via AI |
| **Amazon DynamoDB** | Stores chronicles and evolving style memory |
| **Amazon API Gateway** | Exposes a REST API for the frontend |
| **Amazon S3** | Hosts the static website files (private) |
| **Amazon CloudFront** | Serves the website over HTTPS with CDN caching and OAI |

---

## 🔒 Security & redaction

### Data redaction

Every AI output passes through a comprehensive redaction layer that strips:

- ✅ AWS account IDs (12-digit numbers)
- ✅ IP addresses (IPv4 and IPv6)
- ✅ ARNs (Amazon Resource Names)
- ✅ EC2 instance IDs (`i-*`)
- ✅ S3 bucket names
- ✅ Security group IDs (`sg-*`)
- ✅ VPC and subnet IDs
- ✅ API Gateway and CloudFront IDs
- ✅ UUIDs and GUIDs
- ✅ Email addresses
- ✅ IAM user and role names
- ✅ JWT tokens and API keys

### Infrastructure security

- 🔒 **Private S3 + CloudFront OAI** — the frontend bucket has Block
  Public Access fully enabled; the only read path is through
  CloudFront's Origin Access Identity.
- 🔒 **IAM least privilege** — the Lambda execution role is scoped to
  only `dynamodb:GetItem`/`PutItem`/`Scan`, `bedrock:InvokeModel`/`Converse`,
  and the minimum required CloudWatch Logs actions.
- 🔒 **HTTPS everywhere** — CloudFront, API Gateway, and DynamoDB
  encryption at rest.
- 🔒 **CORS configured** — API Gateway exposes only `/health` and
  `/chronicles`, with strict CORS policies.

---

## 📊 Key metrics

| Metric | Value |
|---|---|
| Total chronicles generated | 409+ |
| AWS services used | 8 |
| Average Lambda duration | ~480ms |
| Average Bedrock latency | ~542ms |
| Lambda memory size | 512 MB |
| Lambda timeout | 60 seconds |
| DynamoDB capacity mode | On-demand (pay-per-request) |

---

## 📁 Project structure

```
sentinels-chronicle/
├── template.yaml              # SAM infrastructure template
├── src/
│   └── app.py                 # Lambda function (main agent logic)
├── frontend/
│   ├── index.html             # Website UI
│   ├── style.css              # Dark theme styling
│   └── app.js                 # Frontend JavaScript (API calls, rendering)
├── events/
│   └── sample-guardduty.json  # Sample GuardDuty finding for local testing
├── README.md
├── LICENSE                    # MIT License
└── .gitignore
```

---

## 🚀 Deployment

### Prerequisites

- AWS CLI configured (`aws configure`)
- AWS SAM CLI installed (`pip install aws-sam-cli`, or `pipx install aws-sam-cli` on Debian/Ubuntu 24+ if you hit an `externally-managed-environment` error)
- Docker (for local testing only)

### Deploy to AWS

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/sentinels-chronicle.git
cd sentinels-chronicle

# 2. Build
sam build

# 3. Validate (optional but recommended)
sam validate --lint

# 4. Deploy with guided mode
sam deploy --guided
```

### Deployment prompts

```
Stack Name: sentinels-chronicle
AWS Region: us-east-1
Parameter BedrockModelId [amazon.nova-lite-v1:0]:
Confirm changes before deploy [y/N]: y
Allow SAM CLI IAM role creation [Y/n]: y
Disable rollback [y/N]: N
Save arguments to configuration file [Y/n]: y
```

> If your region requires a Bedrock cross-region inference profile
> (some APAC regions do), pass it explicitly:
> `sam deploy --parameter-overrides BedrockModelId=<your-inference-profile-id>`

### Environment variables

| Variable | Description | Default |
|---|---|---|
| `CHRONICLE_TABLE` | DynamoDB table for chronicles | `sentinels-chronicle-chronicle` |
| `STYLE_MEMORY_TABLE` | DynamoDB table for style memory | `sentinels-chronicle-style-memory` |
| `BEDROCK_MODEL_ID` | Amazon Bedrock model ID | `amazon.nova-lite-v1:0` |

---

## 🧪 Testing

### Local

```bash
# Invoke with a sample GuardDuty event
sam local invoke SentinelFunction -e events/sample-guardduty.json

# Run the API locally (requires Docker)
sam local start-api
```

### Cloud

```bash
# Generate real GuardDuty sample findings (safe, official AWS testing API)
aws guardduty create-sample-findings --detector-id $DETECTOR_ID --region us-east-1

# Tail Lambda logs
sam logs --stack-name sentinels-chronicle --tail

# Hit the live API
curl https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/health
curl https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/chronicles
```

---

## 💡 How it works

### 1. Event flow

1. GuardDuty detects a security finding
2. EventBridge routes the finding to Lambda
3. Lambda extracts finding details (severity, type, description)
4. Lambda loads the current style memory from DynamoDB
5. Bedrock Nova Lite generates a unique chronicle (180–280 words)
6. The chronicle is stored in DynamoDB
7. Style memory is updated for future stories
8. API Gateway exposes the chronicles
9. S3 + CloudFront serve the web UI

### 2. Prompt engineering

Each Bedrock prompt includes:

- **Event details** — severity, type, title, description
- **Style memory** — evolving narrative preferences from past runs
- **Strict rules** — no invented facts, no attack instructions, no sensitive data
- **Severity-based tone** — low severity → quiet warning; high severity → urgent dark chronicle

### 3. Style memory evolution

The style memory in DynamoDB evolves with each finding, e.g.:

```
"Measured, atmospheric, security-focused."
  → "Measured, atmospheric; current lesson: more tense and concise"
  → "Measured, atmospheric; current lesson: more restrained and precise"
```

---

## 🎯 Challenge submission

Built for the **AWS Weekend Creative Agent Challenge** on AWS Builder Center.

- **Article title:** "Weekend Creative Agent Challenge: The Sentinel's Chronicle"
- **Tags:** `#agents` `#challenge` `#creativeagent`
- **Live app:** sentinels-chronicle-688567278489.s3-website-us-east-1.amazonaws.com
- **API:** 0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/

**What makes it unique:** unlike scheduled creative agents that
generate content on a timer regardless of context, the Sentinel wakes
up only when something real happens.

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.

---

## 🙏 Acknowledgments

- Amazon GuardDuty for security event detection
- Amazon Bedrock Nova Lite for AI story generation
- AWS SAM for simplified infrastructure deployment
- AWS Builder Center for the challenge and inspiration

---

## 📞 Contact & support

- **GitHub Issues:** github.com/YOUR_USERNAME/sentinels-chronicle/issues
- **Live demo:** sentinels-chronicle-688567278489.s3-website-us-east-1.amazonaws.com

---

*The Sentinel watches. The Chronicle endures.* 🗡️

![GitHub stars](https://img.shields.io/github/stars/YOUR_USERNAME/sentinels-chronicle?style=social)
![GitHub forks](https://img.shields.io/github/forks/YOUR_USERNAME/sentinels-chronicle?style=social)
