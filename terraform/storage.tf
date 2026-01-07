# Raw recordings bucket (private)
resource "google_storage_bucket" "raw_recordings" {
  name          = var.raw_bucket_name
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90 # Delete after 90 days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE" # Move to cheaper storage after 30 days
    }
  }
}

# Public clips bucket
resource "google_storage_bucket" "clips" {
  name          = var.clips_bucket_name
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Length", "Accept-Ranges"]
    max_age_seconds = 3600
  }

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# Make clips bucket publicly readable
resource "google_storage_bucket_iam_member" "clips_public" {
  bucket = google_storage_bucket.clips.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Cloud CDN backend bucket for clips
resource "google_compute_backend_bucket" "clips_cdn" {
  count = var.enable_cdn ? 1 : 0

  name        = "${var.service_name}-clips-cdn"
  bucket_name = google_storage_bucket.clips.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}

# URL map for CDN
resource "google_compute_url_map" "clips_cdn" {
  count = var.enable_cdn ? 1 : 0

  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_bucket.clips_cdn[0].id
}

# HTTP proxy for CDN
resource "google_compute_target_http_proxy" "clips_cdn" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.clips_cdn[0].id
}

# Global forwarding rule (external IP)
resource "google_compute_global_forwarding_rule" "clips_cdn" {
  count = var.enable_cdn ? 1 : 0

  name       = "${var.service_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.clips_cdn[0].id
  port_range = "80"
}

# Output CDN IP
output "cdn_ip_address" {
  value       = var.enable_cdn ? google_compute_global_forwarding_rule.clips_cdn[0].ip_address : null
  description = "External IP address for Cloud CDN"
}

output "clips_bucket_url" {
  value       = "gs://${google_storage_bucket.clips.name}"
  description = "GCS URL for clips bucket"
}

output "raw_bucket_url" {
  value       = "gs://${google_storage_bucket.raw_recordings.name}"
  description = "GCS URL for raw recordings bucket"
}
