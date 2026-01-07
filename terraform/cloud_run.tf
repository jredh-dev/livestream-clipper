# Cloud Run service for clip processor
resource "google_cloud_run_service" "clip_processor" {
  name     = "${var.service_name}-processor-${var.environment}"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.clip_processor.email

      containers {
        image = var.clip_processor_image

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "RAW_BUCKET"
          value = google_storage_bucket.raw_recordings.name
        }

        env {
          name  = "CLIPS_BUCKET"
          value = google_storage_bucket.clips.name
        }

        env {
          name  = "ENABLE_TRANSCRIPTION"
          value = var.enable_transcription ? "true" : "false"
        }

        resources {
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }

        ports {
          container_port = 8080
        }
      }

      timeout_seconds       = 600 # 10 minutes for processing large files
      container_concurrency = 1   # Process one clip at a time
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "autoscaling.knative.dev/minScale" = "0"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

# Allow public access to clip processor API
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.clip_processor.name
  location = google_cloud_run_service.clip_processor.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "clip_processor_url" {
  value       = google_cloud_run_service.clip_processor.status[0].url
  description = "URL of the clip processor Cloud Run service"
}
