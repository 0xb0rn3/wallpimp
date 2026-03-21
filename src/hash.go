package main

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"os"
	"sync"
)

type HashDB struct {
	mu   sync.RWMutex
	data map[string]string // md5hex → filepath
	path string
}

func loadHashDB(path string) *HashDB {
	db := &HashDB{path: path, data: make(map[string]string)}
	raw, err := os.ReadFile(path)
	if err != nil {
		return db
	}
	_ = json.Unmarshal(raw, &db.data)
	return db
}

func (db *HashDB) has(digest string) bool {
	db.mu.RLock()
	defer db.mu.RUnlock()
	_, ok := db.data[digest]
	return ok
}

func (db *HashDB) add(digest, fpath string) {
	db.mu.Lock()
	db.data[digest] = fpath
	db.mu.Unlock()
}

func (db *HashDB) save() error {
	db.mu.RLock()
	defer db.mu.RUnlock()
	raw, err := json.MarshalIndent(db.data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(db.path, raw, 0644)
}

func (db *HashDB) cleanup() int {
	db.mu.Lock()
	defer db.mu.Unlock()
	removed := 0
	for h, p := range db.data {
		if _, err := os.Stat(p); os.IsNotExist(err) {
			delete(db.data, h)
			removed++
		}
	}
	return removed
}

func md5hex(data []byte) string {
	sum := md5.Sum(data)
	return hex.EncodeToString(sum[:])
}
