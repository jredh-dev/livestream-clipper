#!/bin/bash
set -e

# Deployment script for livestream-clipper
# This script builds and deploys the entire stack to GCP

PROJECT_ID="dea-noctua"
REGION="us-central1"
SERVICE_NAME="clip-processor"

echo "🚀 Starting deployment for livestream-clipper"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Step 1: Build and push Docker image
echo "📦 Building Docker image..."
cd services/clip-processor

IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME:latest"
docker build -t $IMAGE_NAME .

echo "🔼 Pushing image to GCR..."
docker push $IMAGE_NAME

cd ../..

# Step 2: Deploy infrastructure with Terraform
echo "🏗️  Deploying infrastructure with Terraform..."
cd terraform

terraform init
terraform plan -out=tfplan
echo ""
echo "⚠️  Review the plan above. Press Enter to continue with deployment or Ctrl+C to cancel..."
read

terraform apply tfplan

# Get outputs
CLIP_PROCESSOR_URL=$(terraform output -raw clip_processor_url)
CDN_IP=$(terraform output -raw cdn_ip_address)

cd ..

# Step 3: Update web dashboard with API URL
echo "🌐 Updating web dashboard configuration..."
sed -i.bak "s|REPLACE_WITH_CLOUD_RUN_URL|$CLIP_PROCESSOR_URL|g" web/index.html
rm web/index.html.bak

# Step 4: Deploy web dashboard to GCS
echo "📤 Deploying web dashboard to Cloud Storage..."
CLIPS_BUCKET=$(cd terraform && terraform output -raw clips_bucket_url | sed 's|gs://||')
gsutil cp web/index.html gs://$CLIPS_BUCKET/index.html
gsutil setmeta -h "Content-Type:text/html" -h "Cache-Control:public, max-age=300" gs://$CLIPS_BUCKET/index.html

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "  API: $CLIP_PROCESSOR_URL"
echo "  Dashboard: https://storage.googleapis.com/$CLIPS_BUCKET/index.html"
if [ "$CDN_IP" != "null" ]; then
    echo "  CDN IP: $CDN_IP"
fi
echo ""
echo "📝 Next steps:"
echo "  1. Upload a test recording: gsutil cp test.mp4 gs://dea-noctua-livestream-raw/"
echo "  2. Test the API: curl -X POST $CLIP_PROCESSOR_URL/clip -d '{...}'"
echo "  3. Open the dashboard in your browser"
echo ""
