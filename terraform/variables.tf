variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "dea-noctua"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "service_name" {
  description = "Base name for services"
  type        = string
  default     = "livestream-clipper"
}

variable "raw_bucket_name" {
  description = "Name for raw recordings bucket"
  type        = string
  default     = "dea-noctua-livestream-raw"
}

variable "clips_bucket_name" {
  description = "Name for public clips bucket"
  type        = string
  default     = "dea-noctua-livestream-clips"
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for clips bucket"
  type        = bool
  default     = true
}

variable "enable_transcription" {
  description = "Enable Speech-to-Text transcription"
  type        = bool
  default     = true
}

variable "clip_processor_image" {
  description = "Docker image for clip processor service"
  type        = string
  default     = "gcr.io/dea-noctua/clip-processor:latest"
}
