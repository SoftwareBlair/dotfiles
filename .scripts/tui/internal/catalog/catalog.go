package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Package is one installable item from the bash catalog export.
type Package struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Category    string `json:"category"`
	Default     bool   `json:"default"`
}

// PkgMgrOption is a selectable package manager.
type PkgMgrOption struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	Default bool   `json:"default"`
}

// Profile is a community setup (profiles/<GitHubUsername>.toml).
type Profile struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Default     bool      `json:"default"`
	Packages    []Package `json:"packages"`
}

// Snapshot is the JSON document produced by `setup.sh -c export_wizard_catalog`.
type Snapshot struct {
	Platform           string         `json:"platform"`
	PlatformLabel      string         `json:"platform_label"`
	PkgMgr             string         `json:"pkgmgr"`
	DotfilesDir        string         `json:"dotfiles_dir"`
	DryRun             bool           `json:"dry_run"`
	ActiveProfile      string         `json:"active_profile"`
	ProfileName        string         `json:"profile_name"`
	ProfileDescription string         `json:"profile_description"`
	Packages           []Package      `json:"packages"`
	Profiles           []Profile      `json:"profiles"`
	PkgMgrOptions      []PkgMgrOption `json:"pkgmgr_options"`
}

// LoadFile reads a catalog snapshot from disk (fixtures / tests).
func LoadFile(path string) (Snapshot, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Snapshot{}, err
	}
	return Parse(data)
}

// Parse decodes a catalog snapshot JSON document.
func Parse(data []byte) (Snapshot, error) {
	var snap Snapshot
	if err := json.Unmarshal(data, &snap); err != nil {
		return Snapshot{}, fmt.Errorf("parse catalog json: %w", err)
	}
	return snap, nil
}

// LoadFromSetup runs the bash exporter and returns a snapshot.
func LoadFromSetup(setupPath string, pkgMgr string, dryRun bool, profile string) (Snapshot, error) {
	args := []string{}
	if dryRun {
		args = append(args, "-n")
	}
	if pkgMgr != "" {
		args = append(args, "--pkgmgr", pkgMgr)
	}
	if profile != "" {
		args = append(args, "--profile", profile)
	}
	args = append(args, "-c", "export_wizard_catalog")
	cmd := exec.Command(setupPath, args...)
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return Snapshot{}, fmt.Errorf("export_wizard_catalog failed: %w\n%s", err, strings.TrimSpace(string(ee.Stderr)))
		}
		return Snapshot{}, err
	}
	return Parse(out)
}
