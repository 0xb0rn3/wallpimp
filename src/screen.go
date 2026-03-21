package main

import (
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

type Resolution struct {
	W, H int
}

func (r Resolution) DownloadParams() map[string]string {
	tiers := []int{1280, 1920, 2560, 3840}
	cw := tiers[len(tiers)-1]
	for _, t := range tiers {
		if t >= r.W {
			cw = t
			break
		}
	}
	ch := cw * r.H / r.W
	return map[string]string{
		"w":   strconv.Itoa(cw),
		"h":   strconv.Itoa(ch),
		"fit": "crop",
		"fm":  "jpg",
		"q":   "85",
	}
}

func DetectResolution() Resolution {
	switch runtime.GOOS {
	case "windows":
		return detectWindows()
	case "darwin":
		return detectMacOS()
	default:
		return detectLinux()
	}
}

func detectWindows() Resolution {
	// Use PowerShell to query display resolution
	out, err := exec.Command("powershell", "-NoProfile", "-Command",
		"Add-Type -AssemblyName System.Windows.Forms;"+
			"$s=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;"+
			"Write-Output \"$($s.Width)x$($s.Height)\"",
	).Output()
	if err == nil {
		if r := parseWxH(strings.TrimSpace(string(out))); r.W > 0 {
			return r
		}
	}
	return Resolution{1920, 1080}
}

func detectMacOS() Resolution {
	out, err := exec.Command("system_profiler", "SPDisplaysDataType").Output()
	if err == nil {
		re := regexp.MustCompile(`Resolution:\s*(\d+)\s*x\s*(\d+)`)
		if m := re.FindSubmatch(out); len(m) == 3 {
			w, _ := strconv.Atoi(string(m[1]))
			h, _ := strconv.Atoi(string(m[2]))
			if w > 0 {
				return Resolution{w, h}
			}
		}
	}
	// AppleScript fallback
	script := `tell application "Finder" to get bounds of window of desktop`
	out2, err2 := exec.Command("osascript", "-e", script).Output()
	if err2 == nil {
		parts := strings.Split(strings.TrimSpace(string(out2)), ",")
		if len(parts) == 4 {
			w, _ := strconv.Atoi(strings.TrimSpace(parts[2]))
			h, _ := strconv.Atoi(strings.TrimSpace(parts[3]))
			if w > 0 {
				return Resolution{w, h}
			}
		}
	}
	return Resolution{1920, 1080}
}

func detectLinux() Resolution {
	// xrandr
	out, err := exec.Command("xrandr", "--current").Output()
	if err == nil {
		re := regexp.MustCompile(`connected.*?(\d{3,5})x(\d{3,5})\+`)
		best := Resolution{}
		for _, m := range re.FindAllSubmatch(out, -1) {
			w, _ := strconv.Atoi(string(m[1]))
			h, _ := strconv.Atoi(string(m[2]))
			if w*h > best.W*best.H {
				best = Resolution{w, h}
			}
		}
		if best.W > 0 {
			return best
		}
	}
	// xdpyinfo
	out2, err2 := exec.Command("xdpyinfo").Output()
	if err2 == nil {
		re := regexp.MustCompile(`dimensions:\s+(\d+)x(\d+)`)
		if m := re.FindSubmatch(out2); len(m) == 3 {
			w, _ := strconv.Atoi(string(m[1]))
			h, _ := strconv.Atoi(string(m[2]))
			if w > 0 {
				return Resolution{w, h}
			}
		}
	}
	return Resolution{1920, 1080}
}

func parseWxH(s string) Resolution {
	re := regexp.MustCompile(`(\d+)x(\d+)`)
	m := re.FindStringSubmatch(s)
	if len(m) == 3 {
		w, _ := strconv.Atoi(m[1])
		h, _ := strconv.Atoi(m[2])
		return Resolution{w, h}
	}
	return Resolution{}
}
