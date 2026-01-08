# Livestream Clipper

Auto-clip and edit audio tracks from livestream content with manual timestamp markers.

## Architecture

```
Livestream Source (Twitch/Rumble/OBS)
         ↓
   [Manual Hotkey Press - Captures Timestamps]
         ↓
GCS Bucket: dea-noctua-livestream-raw
         ↓
Cloud Run: clip-processor (Go + ffmpeg)
         ↓
GCS Bucket: dea-noctua-livestream-clips (public)
         ↓
   Cloud CDN (fast delivery)
         ↓
  Web Dashboard (view/share clips)
```

## Features

- **Manual timestamp capture**: Press hotkey to mark clip start/end during livestream
- **Automatic clip generation**: ffmpeg extracts clips from full recording
- **Public CDN URLs**: Instant shareable links to highlights
- **Multi-platform safe**: Self-hosted, no platform censorship
- **Transcription support**: Optional Speech-to-Text with word-level timestamps

## Tech Stack

- **Infrastructure**: Terraform (GCP)
- **Backend**: Go + ffmpeg
- **Storage**: Google Cloud Storage
- **Compute**: Cloud Run (serverless containers)
- **CDN**: Cloud CDN
- **Database**: Cloud Firestore (metadata)

## Project Structure

```
.
├── terraform/          # Infrastructure as Code
│   ├── main.tf
│   ├── storage.tf
│   ├── cloud_run.tf
│   ├── iam.tf
│   └── variables.tf
├── services/
│   └── clip-processor/ # Go service for clip extraction
│       ├── main.go
│       ├── Dockerfile
│       └── handlers/
├── web/                # Dashboard UI
│   └── index.html
├── scripts/            # Deployment and utility scripts
└── docs/               # Documentation
```

## Setup

### Prerequisites

- `gcloud` CLI authenticated
- Terraform v1.14+
- Go 1.21+
- Docker (for local testing)

### Configuration

```bash
# Set GCP project
export GCP_PROJECT_ID="dea-noctua"
export GCP_REGION="us-central1"

# Initialize Terraform
cd terraform
terraform init
terraform plan
terraform apply  # DO NOT RUN YET - review plan first
```

## Usage

### 1. Upload full recording to GCS

```bash
gsutil cp my-stream-2025-01-07.mp4 gs://dea-noctua-livestream-raw/
```

### 2. Create clip via API

```bash
curl -X POST https://clip-processor-<hash>.run.app/clip \
  -H "Content-Type: application/json" \
  -d '{
    "stream_id": "my-stream-2025-01-07",
    "start_time": "00:15:30",
    "end_time": "00:17:45"
  }'
```

### 3. Get public clip URL

```json
{
  "clip_id": "abc123",
  "url": "https://cdn.yourdomain.com/clips/abc123.mp3",
  "duration": 135.0
}
```

## Hotkey Client Options

Choose one:

1. **OBS Script** - Lua/Python script running inside OBS
2. **Desktop App** - Native Go app with global hotkeys
3. **Web Dashboard** - Browser button for manual marking
4. **Mobile App** - iOS/Android companion app

## Cost Estimate (Monthly)

Based on 4 hours streaming/week, 10 clips per stream:

- Cloud Storage: ~$2
- Cloud Run: ~$2
- Speech-to-Text (optional): ~$8
- Cloud CDN: ~$3
- **Total: ~$10-15/month**

## License

AGPL-3.0 - See LICENSE file

## Status

🚧 **Under Development** - Infrastructure ready for deployment
