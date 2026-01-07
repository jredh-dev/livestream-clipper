# Livestream Clipper - Project Summary

**Status**: ✅ Ready for Deployment (DO NOT DEPLOY YET - Review First)

## What We Built

A complete GCP-based infrastructure for livestreaming with manual clip extraction via hotkeys.

### Core Features

1. **Manual Timestamp Capture**: Press hotkey to mark clip start/end during livestream
2. **Automatic Clip Extraction**: ffmpeg-powered clip generation from full recordings
3. **Cloud Storage**: Raw recordings (private) + clips (public CDN)
4. **Web Dashboard**: View, play, and share clips
5. **REST API**: Create clips, list clips, get clip metadata
6. **Multi-Platform Safe**: Self-hosted, avoid platform censorship

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ PHASE 1: RECORDING                                      │
│ OBS/Streaming Software → Upload to GCS                  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 2: HOTKEY MARKING (During Stream)                │
│ Press F9 → Mark Start Time                              │
│ Press F10 → Mark End Time → Call API                    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 3: CLIP PROCESSING                                │
│ Cloud Run Service (Go + ffmpeg)                         │
│  1. Download full recording from GCS                    │
│  2. Extract clip segment with ffmpeg                    │
│  3. Upload clip to public bucket                        │
│  4. Save metadata to Firestore                          │
│  5. Return public CDN URL                               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 4: DELIVERY                                       │
│ Cloud CDN → Fast global delivery                        │
│ Web Dashboard → View/share clips                        │
└─────────────────────────────────────────────────────────┘
```

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Infrastructure** | Terraform | Infrastructure as Code |
| **Backend** | Go 1.21 | Clip processor service |
| **Media Processing** | ffmpeg | Audio extraction |
| **Storage** | Google Cloud Storage | Raw recordings + clips |
| **Compute** | Cloud Run | Serverless containers |
| **CDN** | Cloud CDN | Fast global delivery |
| **Database** | Cloud Firestore | Clip metadata |
| **Container** | Docker | Deployment packaging |
| **Frontend** | Vanilla HTML/CSS/JS | Web dashboard |

## GCP Resources

### Cloud Storage Buckets

1. **dea-noctua-livestream-raw** (Private)
   - Full stream recordings
   - 90-day retention (auto-delete)
   - Moves to Nearline after 30 days
   - Versioning enabled

2. **dea-noctua-livestream-clips** (Public)
   - Extracted audio clips
   - Public read access
   - CORS enabled for web playback
   - CDN-backed

### Cloud Run Service

**clip-processor-dev**
- Image: `gcr.io/dea-noctua/clip-processor:latest`
- Resources: 2 CPU, 2GB RAM
- Timeout: 10 minutes
- Autoscaling: 0-10 instances
- Public endpoint (no auth)

### IAM

**Service Account**: `livestream-clipper-processor@dea-noctua.iam.gserviceaccount.com`
- Permissions:
  - Read from raw bucket
  - Write to clips bucket
  - Firestore read/write
  - Speech-to-Text client (optional)

### Cloud CDN

- Global edge network
- 1-hour cache TTL
- Automatic HTTPS
- External IP: (assigned during deployment)

## API Endpoints

**Base URL**: `https://clip-processor-dev-{hash}.run.app`

### POST /clip
Create a new clip from a recording.

**Request**:
```json
{
  "stream_id": "my-stream-2025-01-07",
  "start_time": "00:15:30",
  "end_time": "00:17:45",
  "title": "Epic moment"
}
```

**Response**:
```json
{
  "clip_id": "abc123-def456-...",
  "url": "https://storage.googleapis.com/dea-noctua-livestream-clips/abc123.mp3",
  "duration": 135.0,
  "message": "Clip created successfully"
}
```

### GET /clips
List all clips.

**Response**:
```json
[
  {
    "clip_id": "abc123",
    "stream_id": "my-stream",
    "title": "Epic moment",
    "start_time": "00:15:30",
    "end_time": "00:17:45",
    "duration": 135.0,
    "url": "https://...",
    "created_at": "2025-01-07T12:34:56Z"
  }
]
```

### GET /clips/{clip_id}
Get specific clip metadata.

### GET /health
Health check endpoint.

## Cost Estimate

### Monthly Cost (4 hours/week streaming, 10 clips/stream)

| Service | Cost |
|---------|------|
| Cloud Storage (raw) | $1.00 |
| Cloud Storage (clips) | $0.10 |
| Cloud Run | $0.50 |
| Cloud CDN | $0.80 |
| Firestore | $0.10 |
| **Total** | **~$2.50/month** |

**With transcription enabled**: Add ~$8/month (Speech-to-Text API)

## Deployment Steps

### Prerequisites

- [x] gcloud CLI authenticated
- [x] Terraform v1.14+
- [x] Docker installed
- [x] GCP project: dea-noctua
- [ ] Review Terraform plan before applying

### Quick Deploy

```bash
cd work/source/jredh-dev/livestream-clipper
./scripts/deploy.sh
```

### Manual Deploy

```bash
# 1. Build and push Docker image
cd services/clip-processor
docker build -t gcr.io/dea-noctua/clip-processor:latest .
docker push gcr.io/dea-noctua/clip-processor:latest

# 2. Deploy infrastructure
cd ../../terraform
terraform init
terraform plan
terraform apply

# 3. Deploy web dashboard
CLIPS_BUCKET=$(terraform output -raw clips_bucket_url | sed 's|gs://||')
API_URL=$(terraform output -raw clip_processor_url)
sed -i "s|REPLACE_WITH_CLOUD_RUN_URL|$API_URL|g" ../web/index.html
gsutil cp ../web/index.html gs://$CLIPS_BUCKET/
```

## Workflow Example

### Before Stream

1. Start OBS with recording enabled
2. Set stream ID (e.g., `stream-2025-01-07`)
3. Configure hotkey client with API URL

### During Stream

1. Stream content as normal
2. Press F9 when interesting moment starts
3. Press F10 when moment ends
4. API creates clip automatically
5. Receive public URL instantly

### After Stream

1. Upload full recording to GCS (if not already uploaded)
2. Review clips in web dashboard
3. Share clip URLs on social media
4. Download clips for editing (optional)

## Hotkey Client Options

Choose one based on your needs:

1. **OBS Script** (Lua/Python) - Recommended for streamers
2. **Desktop App** (Go) - Cross-platform, works with any software
3. **Web Dashboard** - Simple button clicks
4. **Mobile App** - Phone as remote control

See `docs/HOTKEY_CLIENTS.md` for implementations.

## Platform Recommendations

For **risque content**, platform risk ranking:

| Platform | Risk | Notes |
|----------|------|-------|
| Self-hosted (GCS) | ⭐⭐⭐⭐⭐ | Full control, no censorship |
| Rumble | ⭐⭐⭐⭐ | Free speech platform |
| Odysee | ⭐⭐⭐⭐ | Decentralized |
| Twitch | ⭐⭐ | Strict TOS |
| YouTube | ⭐ | High censorship |

**Strategy**: 
- Primary: Self-hosted (this infrastructure)
- Mirrors: Rumble, Odysee
- Avoid: YouTube (until content is vetted)

## File Structure

```
livestream-clipper/
├── README.md
├── LICENSE (AGPL-3.0)
├── .gitignore
├── terraform/
│   ├── main.tf              # Provider, backend, APIs
│   ├── variables.tf         # Configuration variables
│   ├── storage.tf           # GCS buckets, CDN
│   ├── cloud_run.tf         # Clip processor service
│   └── iam.tf               # Service accounts, permissions
├── services/
│   └── clip-processor/
│       ├── main.go          # Go service (REST API)
│       ├── go.mod           # Dependencies
│       └── Dockerfile       # Container image
├── web/
│   └── index.html           # Dashboard UI
├── scripts/
│   └── deploy.sh            # Automated deployment
└── docs/
    ├── DEPLOYMENT.md        # Deployment guide
    └── HOTKEY_CLIENTS.md    # Hotkey implementations
```

## Next Steps

### Before First Deployment

1. **Review Terraform plan**:
   ```bash
   cd terraform
   terraform init
   terraform plan
   ```
   
2. **Check resource naming**:
   - Buckets: `dea-noctua-livestream-*`
   - Service: `clip-processor-dev`
   - Verify no conflicts with existing resources

3. **Estimate costs**:
   - Review storage retention policies
   - Confirm CDN is needed (can disable if budget constrained)

4. **Security review**:
   - Verify IAM permissions are least-privilege
   - Confirm public access is intentional (API and clips bucket)

### After Deployment

1. **Test the API**:
   ```bash
   curl https://{cloud-run-url}/health
   ```

2. **Upload test recording**:
   ```bash
   gsutil cp test.mp4 gs://dea-noctua-livestream-raw/
   ```

3. **Create test clip**:
   ```bash
   curl -X POST {api-url}/clip -d '{"stream_id":"test","start_time":"00:00:10","end_time":"00:00:20"}'
   ```

4. **Verify clip URL**:
   - Check clip is accessible
   - Test playback in browser
   - Verify CDN is serving (check response headers)

### Future Enhancements

- [ ] Transcription with Speech-to-Text API
- [ ] Auto-scrolling transcript UI
- [ ] Playlist support
- [ ] Clip editing (trim, fade)
- [ ] OBS script implementation
- [ ] Desktop hotkey client (Go app)
- [ ] Mobile companion app
- [ ] Analytics (views, shares)
- [ ] Social media auto-posting
- [ ] Multi-stream support

## Support

- **Documentation**: `docs/` directory
- **Issues**: Create GitHub issue
- **Logs**: `gcloud logging read "resource.type=cloud_run_revision"`
- **Monitoring**: Cloud Console → Cloud Run → clip-processor-dev

## License

AGPL-3.0 - See LICENSE file

Copyleft license ensures derivatives remain open source.

---

**Repository**: `work/source/jredh-dev/livestream-clipper`  
**Commit**: `cdcabc9` (Initial commit)  
**Status**: Ready for deployment review  
**Date**: 2025-01-07
