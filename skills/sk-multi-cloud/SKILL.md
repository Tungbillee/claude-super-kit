---
name: sk:multi-cloud
description: Multi-cloud deployment patterns - AWS Lambda/ECS, Azure Functions/Container Apps, GCP Cloud Run/GKE. Decision framework, cost analysis tools, and multi-cloud architecture patterns.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: devops
argument-hint: "[cloud provider or deployment pattern]"
---

# sk:multi-cloud

Guide for deploying applications across AWS, Azure, and GCP — with decision frameworks, cost analysis, and multi-cloud patterns.

## When to Use

- Choosing between cloud providers for a new service
- Deploying serverless functions (Lambda / Azure Functions / Cloud Run)
- Running containerized workloads at scale (ECS / Container Apps / GKE)
- Estimating and comparing cloud costs
- Implementing multi-cloud or cloud-agnostic architectures
- Avoiding vendor lock-in with abstraction patterns

---

## 1. Decision Framework

### Serverless Functions

| Factor | AWS Lambda | Azure Functions | GCP Cloud Run |
|---|---|---|---|
| Cold start | ~100-500ms | ~200-600ms | ~0ms (always warm option) |
| Max execution | 15 min | 10 min | 60 min |
| Max memory | 10 GB | 14 GB | 32 GB |
| Pricing unit | 1ms | 1ms | 100ms |
| Free tier | 1M req/mo | 1M req/mo | 2M req/mo |
| Best for | Event-driven, AWS ecosystem | Microsoft/Azure integration | Containerized, longest timeout |

### Container Orchestration

| Factor | AWS ECS/Fargate | Azure Container Apps | GCP GKE Autopilot |
|---|---|---|---|
| Kubernetes | No (ECS) / Yes (EKS) | Built on K8s (abstracted) | Full K8s managed |
| Scaling | Task-based | KEDA-based (event-driven) | Pod-based |
| Complexity | Medium | Low | Medium-High |
| Cost model | vCPU + memory | Per request + idle | Node pool |
| Best for | AWS-native workloads | Azure ecosystem, DAPR | GCP + K8s expertise |

---

## 2. AWS Lambda

```typescript
// lambda/handler.ts
import { APIGatewayProxyHandler, APIGatewayProxyResult } from 'aws-lambda';

export const handler: APIGatewayProxyHandler = async (event): Promise<APIGatewayProxyResult> => {
  const { httpMethod, path, body } = event;

  try {
    const data = body ? JSON.parse(body) : null;
    // business logic here
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ success: true, data }),
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
```

### Lambda with SAM (Infrastructure as Code)

```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Timeout: 30
    MemorySize: 512
    Runtime: nodejs20.x
    Environment:
      Variables:
        NODE_ENV: production

Resources:
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: dist/
      Handler: handler.handler
      Events:
        Api:
          Type: HttpApi
          Properties:
            Path: /api/{proxy+}
            Method: ANY
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable
```

```bash
# Deploy
sam build && sam deploy --guided
# Local test
sam local invoke ApiFunction -e events/api-event.json
sam local start-api
```

### AWS ECS + Fargate

```yaml
# docker-compose.yml → deploy to ECS
services:
  api:
    image: 123456789.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 1G
    environment:
      - NODE_ENV=production
```

```bash
# Push image to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker build -t my-api .
docker tag my-api:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/my-api:latest

# Deploy to ECS
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment
```

---

## 3. Azure Functions

```typescript
// src/functions/http-trigger.ts
import { app, HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';

export async function httpTrigger(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log(`Processing ${request.method} ${request.url}`);

  try {
    const body = await request.json();
    return { status: 200, jsonBody: { success: true, data: body } };
  } catch (error) {
    context.error('Error:', error);
    return { status: 500, jsonBody: { error: 'Internal server error' } };
  }
}

app.http('httpTrigger', {
  methods: ['GET', 'POST'],
  authLevel: 'function',
  handler: httpTrigger,
});
```

### Azure Container Apps

```bash
# Create Container App
az containerapp create \
  --name my-api \
  --resource-group my-rg \
  --environment my-env \
  --image myacr.azurecr.io/my-api:latest \
  --target-port 3000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 10 \
  --scale-rule-name http-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 50 \
  --env-vars "NODE_ENV=production" "DB_URL=secretref:db-connection"
```

```yaml
# containerapp.yaml
properties:
  configuration:
    ingress:
      external: true
      targetPort: 3000
    secrets:
      - name: db-connection
        value: "postgresql://..."
  template:
    containers:
      - name: api
        image: myacr.azurecr.io/my-api:latest
        resources:
          cpu: 0.5
          memory: 1Gi
        env:
          - name: NODE_ENV
            value: production
          - name: DB_URL
            secretRef: db-connection
    scale:
      minReplicas: 0
      maxReplicas: 10
```

---

## 4. GCP Cloud Run

```yaml
# service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-api
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "100"
        run.googleapis.com/cpu-throttling: "false"   # always-on CPU
    spec:
      containerConcurrency: 80
      timeoutSeconds: 3600
      containers:
        - image: gcr.io/my-project/my-api:latest
          ports: [{ containerPort: 3000 }]
          resources:
            limits:
              cpu: "1"
              memory: 512Mi
          env:
            - name: NODE_ENV
              value: production
            - name: DB_URL
              valueFrom:
                secretKeyRef:
                  name: db-connection
                  key: latest
```

```bash
# Deploy to Cloud Run
gcloud run deploy my-api \
  --image gcr.io/my-project/my-api:latest \
  --region us-central1 \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=100 \
  --concurrency=80 \
  --memory=512Mi \
  --cpu=1

# Apply YAML
gcloud run services replace service.yaml
```

---

## 5. Cost Analysis

### AWS Cost Estimation

```bash
# Lambda cost estimate
# Formula: invocations * duration * memory_GB * $0.0000166667
# Example: 1M req/mo, avg 200ms, 512MB
# Cost = 1,000,000 * 0.2 * 0.5 * 0.0000166667 = $1.67/month + $0.20 request = $1.87/mo

# Use AWS Pricing Calculator
open https://calculator.aws/pricing/2/home
```

```bash
# Cloud cost CLI tools
npm install -g infracost    # Terraform cost estimation
infracost breakdown --path .

# AWS Cost Explorer CLI
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-04-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# GCP cost
gcloud billing budgets list
```

### Cost Comparison Tips

```
Serverless (pay-per-use):
- Good for: spiky traffic, low baseline, < 15min jobs
- Bad for: high steady-state traffic (container cheaper)

Container Always-On:
- GCP Cloud Run min-instances=1 → no cold starts, predictable cost
- AWS ECS Fargate → good for 24/7 services

Break-even point (approx):
- Lambda vs ECS Fargate: ~1M req/day → Fargate cheaper
- Cloud Run vs GKE: 3+ services → GKE shared overhead saves money
```

---

## 6. Multi-Cloud Patterns

### Abstraction Layer (avoid lock-in)

```typescript
// lib/storage-provider.ts — cloud-agnostic storage interface
interface StorageProvider {
  upload(key: string, data: Buffer, content_type: string): Promise<string>;
  download(key: string): Promise<Buffer>;
  delete(key: string): Promise<void>;
  getSignedUrl(key: string, expires_in: number): Promise<string>;
}

// lib/providers/aws-s3-provider.ts
class AWSS3Provider implements StorageProvider {
  async upload(key: string, data: Buffer, content_type: string): Promise<string> {
    const { S3Client, PutObjectCommand } = await import('@aws-sdk/client-s3');
    // implementation
    return `https://${this.bucket}.s3.amazonaws.com/${key}`;
  }
  // ...
}

// lib/providers/gcp-gcs-provider.ts
class GCPGCSProvider implements StorageProvider { /* ... */ }

// lib/providers/azure-blob-provider.ts
class AzureBlobProvider implements StorageProvider { /* ... */ }

// Factory
function createStorageProvider(provider: 'aws' | 'gcp' | 'azure'): StorageProvider {
  switch (provider) {
    case 'aws': return new AWSS3Provider(process.env.S3_BUCKET!);
    case 'gcp': return new GCPGCSProvider(process.env.GCS_BUCKET!);
    case 'azure': return new AzureBlobProvider(process.env.AZURE_CONTAINER!);
  }
}

export const storage = createStorageProvider(
  (process.env.CLOUD_PROVIDER as any) ?? 'aws'
);
```

### Multi-Region Deployment (Terraform)

```hcl
# main.tf — deploy same service to multiple clouds
module "aws_deployment" {
  source = "./modules/aws-lambda"
  region = "us-east-1"
  image  = var.docker_image
}

module "gcp_deployment" {
  source  = "./modules/gcp-cloud-run"
  region  = "us-central1"
  image   = var.docker_image
}

# Route traffic based on geography (Cloudflare)
```

---

## Reference Docs

- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Azure Functions v4 (Node.js)](https://learn.microsoft.com/en-us/azure/azure-functions/functions-node-upgrade-v4)
- [GCP Cloud Run](https://cloud.google.com/run/docs)
- [Infracost](https://www.infracost.io/)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang nhắm tới cloud provider nào? (AWS / Azure / GCP / multi-cloud)"
2. "Workload type: serverless functions / containerized API / background jobs / microservices?"
3. "Expected traffic: spiky/unpredictable hay steady-state?"
4. "Bạn đang dùng Infrastructure as Code không? (Terraform / Pulumi / CDK)"

Cung cấp config deployment cụ thể và cost estimate cho use case của họ.
