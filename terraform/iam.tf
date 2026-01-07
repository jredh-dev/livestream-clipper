# Service account for clip processor
resource "google_service_account" "clip_processor" {
  account_id   = "${var.service_name}-processor"
  display_name = "Livestream Clip Processor Service Account"
  description  = "Service account for Cloud Run clip processor service"
}

# Grant storage permissions to clip processor
resource "google_storage_bucket_iam_member" "processor_raw_read" {
  bucket = google_storage_bucket.raw_recordings.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.clip_processor.email}"
}

resource "google_storage_bucket_iam_member" "processor_clips_write" {
  bucket = google_storage_bucket.clips.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.clip_processor.email}"
}

# Grant Speech-to-Text permissions (if enabled)
resource "google_project_iam_member" "processor_speech" {
  count = var.enable_transcription ? 1 : 0

  project = var.project_id
  role    = "roles/speechtotext.client"
  member  = "serviceAccount:${google_service_account.clip_processor.email}"
}

# Grant Firestore permissions for metadata storage
resource "google_project_iam_member" "processor_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.clip_processor.email}"
}

output "clip_processor_service_account" {
  value       = google_service_account.clip_processor.email
  description = "Email of the clip processor service account"
}
