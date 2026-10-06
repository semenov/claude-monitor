// claude-monitor serves the output of `claude -p /usage` as JSON.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

const cacheTTL = 60 * time.Second

type fetcher struct {
	mu   sync.Mutex
	last *Usage
	err  error
}

func (f *fetcher) get(force bool) (*Usage, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if !force && f.last != nil && time.Since(f.last.FetchedAt) < cacheTTL {
		return f.last, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, claudeBin(), "-p", "/usage")
	cmd.Dir = os.TempDir()
	out, err := cmd.Output()
	if err != nil {
		log.Printf("claude -p /usage: %v", err)
		if f.last != nil {
			return f.last, nil // serve stale data rather than nothing
		}
		return nil, err
	}
	u := parseUsage(string(out), time.Now().Truncate(time.Second))
	f.last = &u
	return f.last, nil
}

// claudeBin finds the claude CLI; launchd's login shell may not have ~/.local/bin on PATH.
func claudeBin() string {
	if p := os.Getenv("CLAUDE_BIN"); p != "" {
		return p
	}
	if p, err := exec.LookPath("claude"); err == nil {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "bin", "claude")
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "4100"
	}
	f := &fetcher{}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/usage", func(w http.ResponseWriter, r *http.Request) {
		u, err := f.get(r.URL.Query().Get("refresh") == "1")
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			w.WriteHeader(http.StatusBadGateway)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(u)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok\n"))
	})

	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
