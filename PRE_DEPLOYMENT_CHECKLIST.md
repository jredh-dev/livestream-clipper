# Pre-Deployment Checklist

Before running `./scripts/deploy.sh`, verify the following:

## ✅ Prerequisites

- [ ] **gcloud authenticated**: Run `gcloud auth list` to verify
- [ ] **Docker running**: Run `docker ps` to verify
- [ ] **Terraform installed**: Run `terraform version` (need v1.14+)
- [ ] **GCP project set**: Run `gcloud config get-value project` (should show `dea-noctua`)
- [ ] **Repository is on `jredh-dev` GitHub org**: Ready to push to GitHub

## ✅ Configuration Review

### Terraform Variables (`terraform/variables.tf`)

- [ ] `project_id = "dea-noctua"` - Correct project
- [ ] `region = "us-central1"` - Desired region
- [ ] `raw_bucket_name = "dea-noctua-livestream-raw"` - Not already in use
- [ ] `clips_bucket_name = "dea-noctua-livestream-clips"` - Not already in use
- [ ] `enable_cdn = true` - Want CDN? (adds cost)
- [ ] `enable_transcription = true` - Want transcription? (adds ~$8/month)

### Service Configuration

- [ ] `clip_processor_image` will be built and pushed to GCR
- [ ] Service account name doesn't conflict with existing accounts
- [ ] IAM permissions are appropriate (read raw, write clips, firestore)

## ✅ Cost Verification

Estimated monthly cost: **$2.50 - $10/month**

- Storage (raw + clips): ~$1.10
- Cloud Run: ~$0.50
- CDN: ~$0.80
- Firestore: ~$0.10
- **Transcription (optional)**: ~$8.00

**Action**: Confirm budget is acceptable

## ✅ Security Review

- [ ] **Public API endpoint**: Clip processor will be publicly accessible (no auth)
- [ ] **Public clips bucket**: Anyone with URL can access clips
- [ ] **Private raw bucket**: Full recordings are private
- [ ] **Service account permissions**: Least privilege (read raw, write clips)
- [ ] **CORS enabled**: Clips bucket allows web playback

**Action**: Confirm public access is intentional

## ✅ Deployment Plan Review

Run this to see what Terraform will create:

```bash
cd terraform
terraform init
terraform plan
```

Expected resources:
- 2 GCS buckets
- 1 Cloud Run service
- 1 Service account
- 3 IAM bindings
- 4 CDN resources (if enabled)
- 6 GCP API enablements

**Action**: Review plan output before proceeding

## ✅ Terraform State

- [ ] Remote state bucket exists: `gs://dea-noctua-terraform-state/`
- [ ] State prefix set to: `livestream-clipper`
- [ ] No conflicting state files

Verify:
```bash
gsutil ls gs://dea-noctua-terraform-state/
```

## ✅ Test Plan

After deployment, you'll test:

1. **Health check**: `curl {api-url}/health`
2. **Upload test file**: `gsutil cp test.mp4 gs://dea-noctua-livestream-raw/`
3. **Create clip**: `curl -X POST {api-url}/clip -d '{...}'`
4. **Verify clip**: Open returned URL in browser
5. **Check dashboard**: Visit `https://storage.googleapis.com/{clips-bucket}/index.html`

**Action**: Have test video file ready (~1-2 min duration)

## ✅ Rollback Plan

If deployment fails or needs to be reverted:

```bash
cd terraform
terraform destroy
```

**Warning**: This will delete all clips and recordings!

Alternative: Keep infrastructure, just stop the service:
```bash
gcloud run services delete clip-processor-dev --region=us-central1
```

## ✅ GitHub Repository

- [ ] Create GitHub repo: `github.com/jredh-dev/livestream-clipper`
- [ ] Push local repository
- [ ] Set repository to private (contains GCP project details)
- [ ] Add AGPL-3.0 license to GitHub

```bash
# After creating repo on GitHub
cd work/source/jredh-dev/livestream-clipper
git remote add origin git@github.com:jredh-dev/livestream-clipper.git
git push -u origin main
```

## ✅ Post-Deployment

After successful deployment:

- [ ] Save Cloud Run URL for hotkey client configuration
- [ ] Save CDN IP address for DNS configuration (if using custom domain)
- [ ] Update `web/index.html` with actual API URL
- [ ] Test clip creation end-to-end
- [ ] Choose and implement hotkey client (OBS script, desktop app, etc.)
- [ ] Document actual costs in first month for future reference

## 🚀 Ready to Deploy?

If all checkboxes above are complete:

```bash
cd work/source/jredh-dev/livestream-clipper
./scripts/deploy.sh
```

The script will:
1. Build and push Docker image (~5 min)
2. Deploy Terraform infrastructure (~3 min)
3. Update web dashboard (~1 min)
4. Output service URLs

**Total time**: ~10 minutes

## 🛑 Stop! Review First

**DO NOT DEPLOY** if:
- Any checkbox above is unchecked
- You haven't reviewed Terraform plan
- Budget is not approved
- Test file is not ready
- GitHub repository is not created

**Questions to resolve first**:
1. Where will you stream from? (OBS, Twitch, Rumble, custom RTMP?)
2. How will recordings reach GCS? (manual upload, automated sync?)
3. Which hotkey client will you use? (OBS script, desktop app, web?)
4. Do you want transcription enabled? (+$8/month)
5. Do you need CDN or is direct bucket access sufficient?

---

**Status**: Infrastructure is ready, pending your deployment approval.
