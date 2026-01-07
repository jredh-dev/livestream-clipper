package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

type ClipRequest struct {
	StreamID  string `json:"stream_id"`
	StartTime string `json:"start_time"` // Format: HH:MM:SS or seconds
	EndTime   string `json:"end_time"`   // Format: HH:MM:SS or seconds
	Title     string `json:"title,omitempty"`
}

type ClipResponse struct {
	ClipID   string  `json:"clip_id"`
	URL      string  `json:"url"`
	Duration float64 `json:"duration"`
	Message  string  `json:"message"`
}

type ClipMetadata struct {
	ClipID    string    `firestore:"clip_id"`
	StreamID  string    `firestore:"stream_id"`
	Title     string    `firestore:"title"`
	StartTime string    `firestore:"start_time"`
	EndTime   string    `firestore:"end_time"`
	Duration  float64   `firestore:"duration"`
	URL       string    `firestore:"url"`
	CreatedAt time.Time `firestore:"created_at"`
}

var (
	projectID       = os.Getenv("GCP_PROJECT_ID")
	rawBucket       = os.Getenv("RAW_BUCKET")
	clipsBucket     = os.Getenv("CLIPS_BUCKET")
	storageClient   *storage.Client
	firestoreClient *firestore.Client
)

func init() {
	ctx := context.Background()
	var err error

	// Initialize GCS client
	storageClient, err = storage.NewClient(ctx)
	if err != nil {
		log.Fatalf("Failed to create storage client: %v", err)
	}

	// Initialize Firestore client
	firestoreClient, err = firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create firestore client: %v", err)
	}
}

func main() {
	r := mux.NewRouter()

	// Health check
	r.HandleFunc("/health", healthHandler).Methods("GET")

	// Clip creation endpoint
	r.HandleFunc("/clip", createClipHandler).Methods("POST")

	// List clips endpoint
	r.HandleFunc("/clips", listClipsHandler).Methods("GET")

	// Get specific clip metadata
	r.HandleFunc("/clips/{clip_id}", getClipHandler).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting clip processor service on port %s", port)
	log.Printf("Raw bucket: %s", rawBucket)
	log.Printf("Clips bucket: %s", clipsBucket)

	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "clip-processor",
	})
}

func createClipHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var req ClipRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate request
	if req.StreamID == "" || req.StartTime == "" || req.EndTime == "" {
		http.Error(w, "Missing required fields: stream_id, start_time, end_time", http.StatusBadRequest)
		return
	}

	// Generate unique clip ID
	clipID := uuid.New().String()

	// Download raw file from GCS
	rawFile := fmt.Sprintf("%s.mp4", req.StreamID)
	localRawPath := filepath.Join("/tmp", rawFile)

	log.Printf("Downloading raw file: %s from bucket: %s", rawFile, rawBucket)
	if err := downloadFromGCS(ctx, rawBucket, rawFile, localRawPath); err != nil {
		log.Printf("Error downloading raw file: %v", err)
		http.Error(w, fmt.Sprintf("Failed to download raw file: %v", err), http.StatusInternalServerError)
		return
	}
	defer os.Remove(localRawPath)

	// Extract clip using ffmpeg
	clipFileName := fmt.Sprintf("%s.mp3", clipID)
	localClipPath := filepath.Join("/tmp", clipFileName)

	log.Printf("Extracting clip from %s to %s", req.StartTime, req.EndTime)
	duration, err := extractClip(localRawPath, localClipPath, req.StartTime, req.EndTime)
	if err != nil {
		log.Printf("Error extracting clip: %v", err)
		http.Error(w, fmt.Sprintf("Failed to extract clip: %v", err), http.StatusInternalServerError)
		return
	}
	defer os.Remove(localClipPath)

	// Upload clip to public bucket
	log.Printf("Uploading clip to bucket: %s", clipsBucket)
	if err := uploadToGCS(ctx, clipsBucket, clipFileName, localClipPath); err != nil {
		log.Printf("Error uploading clip: %v", err)
		http.Error(w, fmt.Sprintf("Failed to upload clip: %v", err), http.StatusInternalServerError)
		return
	}

	// Generate public URL
	clipURL := fmt.Sprintf("https://storage.googleapis.com/%s/%s", clipsBucket, clipFileName)

	// Save metadata to Firestore
	metadata := ClipMetadata{
		ClipID:    clipID,
		StreamID:  req.StreamID,
		Title:     req.Title,
		StartTime: req.StartTime,
		EndTime:   req.EndTime,
		Duration:  duration,
		URL:       clipURL,
		CreatedAt: time.Now(),
	}

	if _, err := firestoreClient.Collection("clips").Doc(clipID).Set(ctx, metadata); err != nil {
		log.Printf("Error saving metadata: %v", err)
		// Don't fail the request, clip is already uploaded
	}

	// Return response
	response := ClipResponse{
		ClipID:   clipID,
		URL:      clipURL,
		Duration: duration,
		Message:  "Clip created successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func listClipsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Query Firestore for all clips
	iter := firestoreClient.Collection("clips").OrderBy("created_at", firestore.Desc).Documents(ctx)
	defer iter.Stop()

	var clips []ClipMetadata
	for {
		doc, err := iter.Next()
		if err != nil {
			break
		}

		var clip ClipMetadata
		if err := doc.DataTo(&clip); err != nil {
			log.Printf("Error parsing clip: %v", err)
			continue
		}
		clips = append(clips, clip)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(clips)
}

func getClipHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	clipID := vars["clip_id"]

	doc, err := firestoreClient.Collection("clips").Doc(clipID).Get(ctx)
	if err != nil {
		http.Error(w, "Clip not found", http.StatusNotFound)
		return
	}

	var clip ClipMetadata
	if err := doc.DataTo(&clip); err != nil {
		http.Error(w, "Error parsing clip", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(clip)
}

func downloadFromGCS(ctx context.Context, bucket, object, destPath string) error {
	rc, err := storageClient.Bucket(bucket).Object(object).NewReader(ctx)
	if err != nil {
		return fmt.Errorf("failed to open object reader: %w", err)
	}
	defer rc.Close()

	f, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("failed to create local file: %w", err)
	}
	defer f.Close()

	if _, err := f.ReadFrom(rc); err != nil {
		return fmt.Errorf("failed to download file: %w", err)
	}

	return nil
}

func uploadToGCS(ctx context.Context, bucket, object, srcPath string) error {
	f, err := os.Open(srcPath)
	if err != nil {
		return fmt.Errorf("failed to open local file: %w", err)
	}
	defer f.Close()

	wc := storageClient.Bucket(bucket).Object(object).NewWriter(ctx)
	wc.ContentType = "audio/mpeg"
	wc.CacheControl = "public, max-age=86400"

	if _, err := wc.ReadFrom(f); err != nil {
		return fmt.Errorf("failed to upload file: %w", err)
	}

	if err := wc.Close(); err != nil {
		return fmt.Errorf("failed to close writer: %w", err)
	}

	return nil
}

func extractClip(inputPath, outputPath, startTime, endTime string) (float64, error) {
	// ffmpeg command to extract audio clip
	// -i input.mp4 -ss START_TIME -to END_TIME -vn -acodec libmp3lame -q:a 2 output.mp3
	cmd := exec.Command("ffmpeg",
		"-i", inputPath,
		"-ss", startTime,
		"-to", endTime,
		"-vn",                   // No video
		"-acodec", "libmp3lame", // MP3 codec
		"-q:a", "2", // High quality
		"-y", // Overwrite output
		outputPath,
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return 0, fmt.Errorf("ffmpeg failed: %w, output: %s", err, string(output))
	}

	// Get duration of clip using ffprobe
	durationCmd := exec.Command("ffprobe",
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		outputPath,
	)

	durationOutput, err := durationCmd.Output()
	if err != nil {
		return 0, fmt.Errorf("ffprobe failed: %w", err)
	}

	var duration float64
	if _, err := fmt.Sscanf(string(durationOutput), "%f", &duration); err != nil {
		return 0, fmt.Errorf("failed to parse duration: %w", err)
	}

	return duration, nil
}
