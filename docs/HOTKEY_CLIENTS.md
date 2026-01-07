# Hotkey Client Options

The hotkey client is the tool you'll use during livestreaming to mark clip timestamps. When you press a hotkey, it captures the current timestamp and sends it to the clip processor API.

## Option 1: OBS Script (Recommended for Streamers)

### Overview
A Lua or Python script that runs inside OBS and captures timestamps during your stream.

### Pros
- Integrated directly in OBS
- No separate application needed
- Timestamps are perfectly synced with recording
- Can show visual feedback in OBS

### Implementation

**Lua Script** (`obs-clipper.lua`):
```lua
obs = obslua

-- Settings
api_url = ""
stream_id = ""
start_time = nil

function mark_start()
    start_time = os.time()
    obs.script_log(obs.LOG_INFO, "Clip start marked: " .. start_time)
end

function mark_end()
    if start_time == nil then
        obs.script_log(obs.LOG_WARNING, "No start time set!")
        return
    end
    
    end_time = os.time()
    
    -- Calculate duration
    duration = end_time - start_time
    
    -- Send to API
    create_clip(start_time, end_time)
    
    start_time = nil
end

function create_clip(start_ts, end_ts)
    -- Convert to HH:MM:SS format
    start_formatted = format_timestamp(start_ts)
    end_formatted = format_timestamp(end_ts)
    
    -- Make HTTP POST request
    local json_body = string.format([[
        {
            "stream_id": "%s",
            "start_time": "%s",
            "end_time": "%s"
        }
    ]], stream_id, start_formatted, end_formatted)
    
    -- Use OBS HTTP client (requires obs-websocket plugin)
    -- Or shell out to curl
    local command = string.format(
        'curl -X POST %s/clip -H "Content-Type: application/json" -d \'%s\'',
        api_url, json_body
    )
    os.execute(command)
    
    obs.script_log(obs.LOG_INFO, "Clip created!")
end

function format_timestamp(ts)
    return os.date("!%H:%M:%S", ts)
end

-- OBS Script Hooks
function script_description()
    return "Livestream Clipper - Mark timestamps during stream"
end

function script_properties()
    local props = obs.obs_properties_create()
    
    obs.obs_properties_add_text(props, "api_url", "API URL", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "stream_id", "Stream ID", obs.OBS_TEXT_DEFAULT)
    
    return props
end

function script_update(settings)
    api_url = obs.obs_data_get_string(settings, "api_url")
    stream_id = obs.obs_data_get_string(settings, "stream_id")
end

function script_load(settings)
    local hotkey_id_start = obs.obs_hotkey_register_frontend("clipper_mark_start", "Mark Clip Start", mark_start)
    local hotkey_id_end = obs.obs_hotkey_register_frontend("clipper_mark_end", "Mark Clip End", mark_end)
    
    local hotkey_save_array_start = obs.obs_data_get_array(settings, "clipper_mark_start")
    local hotkey_save_array_end = obs.obs_data_get_array(settings, "clipper_mark_end")
    
    obs.obs_hotkey_load(hotkey_id_start, hotkey_save_array_start)
    obs.obs_hotkey_load(hotkey_id_end, hotkey_save_array_end)
    
    obs.obs_data_array_release(hotkey_save_array_start)
    obs.obs_data_array_release(hotkey_save_array_end)
end
```

### Installation

1. Open OBS
2. Tools → Scripts
3. Click "+" to add script
4. Select `obs-clipper.lua`
5. Configure:
   - API URL: Your Cloud Run URL
   - Stream ID: Unique identifier for this stream
6. Go to Settings → Hotkeys
7. Assign keys to "Mark Clip Start" and "Mark Clip End"

---

## Option 2: Desktop App (Cross-Platform)

### Overview
A standalone Go application with global hotkeys that runs alongside OBS.

### Pros
- Works with any streaming software
- Cleaner separation of concerns
- Can run on different machine than stream PC
- Easier to debug and update

### Implementation

**Go Desktop App** (`cmd/hotkey-client/main.go`):
```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
    
    "github.com/getlantern/systray"
    "github.com/robotn/gohook"
)

var (
    apiURL    = "https://your-cloud-run-url.run.app"
    streamID  = "stream-2025-01-07"
    startTime *time.Time
)

func main() {
    systray.Run(onReady, onExit)
}

func onReady() {
    systray.SetTitle("Clipper")
    systray.SetTooltip("Livestream Clipper Hotkeys Active")
    
    mQuit := systray.AddMenuItem("Quit", "Exit the application")
    
    go func() {
        <-mQuit.ClickedCh
        systray.Quit()
    }()
    
    // Register global hotkeys
    go registerHotkeys()
}

func onExit() {
    log.Println("Clipper stopped")
}

func registerHotkeys() {
    // F9 = Mark Start
    // F10 = Mark End
    
    hook.Register(hook.KeyDown, []string{"f9"}, func(e hook.Event) {
        markStart()
    })
    
    hook.Register(hook.KeyDown, []string{"f10"}, func(e hook.Event) {
        markEnd()
    })
    
    s := hook.Start()
    <-hook.Process(s)
}

func markStart() {
    now := time.Now()
    startTime = &now
    log.Printf("✓ Clip start marked: %s", now.Format("15:04:05"))
    showNotification("Clip Start", "Marked at " + now.Format("15:04:05"))
}

func markEnd() {
    if startTime == nil {
        log.Println("⚠ No start time set!")
        showNotification("Error", "Mark start first!")
        return
    }
    
    endTime := time.Now()
    
    go createClip(*startTime, endTime)
    
    startTime = nil
}

func createClip(start, end time.Time) {
    // Calculate offset from stream start (assuming stream started at midnight for simplicity)
    // In production, you'd track actual stream start time
    
    startFormatted := start.Format("15:04:05")
    endFormatted := end.Format("15:04:05")
    
    payload := map[string]string{
        "stream_id":  streamID,
        "start_time": startFormatted,
        "end_time":   endFormatted,
        "title":      fmt.Sprintf("Clip %s", start.Format("15:04")),
    }
    
    jsonData, _ := json.Marshal(payload)
    
    resp, err := http.Post(
        apiURL+"/clip",
        "application/json",
        bytes.NewBuffer(jsonData),
    )
    
    if err != nil {
        log.Printf("✗ Failed to create clip: %v", err)
        showNotification("Error", "Failed to create clip")
        return
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != 200 {
        log.Printf("✗ API returned status %d", resp.StatusCode)
        showNotification("Error", fmt.Sprintf("API error: %d", resp.StatusCode))
        return
    }
    
    var result map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&result)
    
    log.Printf("✓ Clip created: %s", result["url"])
    showNotification("Clip Created!", "URL copied to clipboard")
    
    // Copy URL to clipboard
    copyToClipboard(result["url"].(string))
}

func showNotification(title, message string) {
    // Platform-specific notification
    // macOS: osascript
    // Windows: PowerShell
    // Linux: notify-send
}

func copyToClipboard(text string) {
    // Platform-specific clipboard
}
```

### Installation

```bash
# Build for your platform
cd cmd/hotkey-client
go build -o clipper

# Run
./clipper

# Configure
# Edit config.json with your API URL and stream ID
```

---

## Option 3: Web Dashboard Button

### Overview
Simple browser-based button clicking during stream.

### Pros
- No installation required
- Works on any device (even mobile)
- Easy to use

### Cons
- Must have browser tab open
- Less convenient than hotkeys
- Timestamps might be slightly delayed

### Implementation

Already built into the web dashboard (`web/index.html`). Just add two buttons:

```html
<button onclick="markStart()">Mark Start (F9)</button>
<button onclick="markEnd()">Mark End (F10)</button>
```

---

## Option 4: Mobile App (iOS/Android)

### Overview
Companion mobile app for marking clips on your phone.

### Pros
- Use phone as remote control
- Don't need keyboard access
- Can hand to moderator

### Cons
- Requires app development
- App store deployment
- Network latency

### Implementation

**React Native** or **Flutter** app with two big buttons:
- "START CLIP"
- "END CLIP"

Connects to same API endpoint.

---

## Recommendation

**For most users**: Start with **Option 1 (OBS Script)**

**If you need more flexibility**: Use **Option 2 (Desktop App)**

**For quick testing**: Use **Option 3 (Web Dashboard)**

**For team streams**: Build **Option 4 (Mobile App)**

---

## Next Steps

1. Choose your hotkey client option
2. Configure with your Cloud Run API URL
3. Set your stream ID before each stream
4. Test with a practice recording
5. Go live and start clipping!
