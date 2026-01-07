# Deployment Guide

This guide walks through deploying the livestream-clipper infrastructure to GCP.

## Prerequisites

Before deploying, ensure you have:

- [x] `gcloud` CLI authenticated (`gcloud auth login`)
- [x] Terraform v1.14+ installed
- [x] Docker installed and running
- [x] GCP project `dea-noctua` configured
- [x] Required GCP APIs enabled (script will enable them)
- [x] Sufficient GCP permissions (Owner or Editor role)

## Deployment Steps

### Option 1: Automated Deployment (Recommended)

```bash
# From project root
./scripts/deploy.sh
```

This will:
1. Build and push Docker image to GCR
2. Deploy infrastructure with Terraform
3. Update web dashboard with API URL
4. Deploy dashboard to Cloud Storage

### Option 2: Manual Deployment

If you prefer to deploy step-by-step:

#### Step 1: Build Docker Image

```bash
cd services/clip-processor
docker build -t gcr.io/dea-noctua/clip-processor:latest .
docker push gcr.io/dea-noctua/clip-processor:latest
cd ../..
```

#### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# Save outputs
terraform output > ../outputs.txt

cd ..
```

#### Step 3: Configure Web Dashboard

```bash
# Get API URL from Terraform output
API_URL=$(cd terraform && terraform output -raw clip_processor_url)

# Update dashboard
sed -i "s|REPLACE_WITH_CLOUD_RUN_URL|$API_URL|g" web/index.html
```

#### Step 4: Deploy Dashboard

```bash
# Upload to clips bucket
gsutil cp web/index.html gs://dea-noctua-livestream-clips/
gsutil setmeta -h "Content-Type:text/html" gs://dea-noctua-livestream-clips/index.html
```

## Post-Deployment

### 1. Verify Services

```bash
# Check Cloud Run service
gcloud run services describe clip-processor-dev --region=us-central1

# Check storage buckets
gsutil ls gs://dea-noctua-livestream-raw/
gsutil ls gs://dea-noctua-livestream-clips/

# Test API health
curl https://<your-cloud-run-url>/health
```

### 2. Upload Test Recording

```bash
# Upload a test video/audio file
gsutil cp test-stream.mp4 gs://dea-noctua-livestream-raw/
```

### 3. Create Test Clip

```bash
# Replace with your Cloud Run URL
API_URL="https://clip-processor-dev-xxxxx.run.app"

curl -X POST $API_URL/clip \
  -H "Content-Type: application/json" \
  -d '{
    "stream_id": "test-stream",
    "start_time": "00:00:10",
    "end_time": "00:00:20",
    "title": "Test Clip"
  }'
```

### 4. Access Dashboard

Open the dashboard URL in your browser:
```
https://storage.googleapis.com/dea-noctua-livestream-clips/index.html
```

## Infrastructure Overview

After deployment, you'll have:

### Cloud Storage Buckets

1. **dea-noctua-livestream-raw**
   - Private bucket for full recordings
   - 90-day retention (auto-delete)
   - Moves to Nearline storage after 30 days

2. **dea-noctua-livestream-clips**
   - Public bucket for clips
   - CORS enabled for web playback
   - CDN-backed for fast delivery

### Cloud Run Service

- **clip-processor-dev**
  - Serverless container (scales 0-10 instances)
  - 2 CPU, 2GB RAM per instance
  - 10-minute timeout for large files
  - Public endpoint (no auth required)

### Cloud CDN

- Global edge network for clip delivery
- 1-hour cache TTL
- Automatic HTTPS

### Firestore Database

- Stores clip metadata (titles, timestamps, URLs)
- Native mode (not Datastore mode)

## Cost Estimation

Based on 4 hours/week streaming, 10 clips per stream:

| Service | Usage | Cost/Month |
|---------|-------|------------|
| Cloud Storage (raw) | ~50GB | $1.00 |
| Cloud Storage (clips) | ~5GB | $0.10 |
| Cloud Run (processing) | ~40 requests | $0.50 |
| Cloud CDN | ~10GB transfer | $0.80 |
| Firestore | 1000 reads/writes | $0.10 |
| **Total** | | **~$2.50** |

(Transcription adds ~$8/month if enabled)

## Troubleshooting

### Cloud Run Deploy Fails

```bash
# Check service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=clip-processor-dev" --limit 50

# Redeploy manually
gcloud run deploy clip-processor-dev \
  --image gcr.io/dea-noctua/clip-processor:latest \
  --region us-central1 \
  --allow-unauthenticated
```

### ffmpeg Not Found in Container

Rebuild Docker image ensuring ffmpeg is installed:
```bash
docker build --no-cache -t gcr.io/dea-noctua/clip-processor:latest services/clip-processor/
```

### Clip Creation Hangs

Check Cloud Run timeout (max 10 minutes):
```bash
# For very large files, increase timeout
gcloud run services update clip-processor-dev \
  --timeout=900 \
  --region=us-central1
```

### Dashboard Shows "Loading clips..."

1. Check browser console for CORS errors
2. Verify API URL in `web/index.html` is correct
3. Check Cloud Run service is publicly accessible

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

**Warning**: This will delete:
- All clips
- All raw recordings
- Service accounts
- Cloud Run service
- CDN configuration

Terraform state bucket (`dea-noctua-terraform-state`) will NOT be deleted.

## Next Steps

1. **Set up hotkey client** - See `docs/HOTKEY_CLIENTS.md`
2. **Configure OBS** - See `docs/OBS_SETUP.md`
3. **Enable transcription** - Set `enable_transcription = true` in `terraform/variables.tf`
4. **Add custom domain** - Configure Cloud CDN with your domain
5. **Set up monitoring** - Add Cloud Monitoring alerts

## Support

For issues or questions:
- Check logs: `gcloud logging read ...`
- Review Terraform state: `terraform show`
- File issues on GitHub: https://github.com/jredh-dev/livestream-clipper
