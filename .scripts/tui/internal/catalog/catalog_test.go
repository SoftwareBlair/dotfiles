package catalog_test

import (
	"path/filepath"
	"runtime"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
)

func TestParseMultiProfileFixture(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_default_and_blair.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(snap.Profiles) != 2 {
		t.Fatalf("profiles=%d", len(snap.Profiles))
	}
	if snap.ActiveProfile != "default" {
		t.Fatalf("active=%s", snap.ActiveProfile)
	}
	shell := snap.ShellPackages()
	if len(shell) < 1 {
		t.Fatal("expected shell packages")
	}
}

func TestParseMigrateFixture(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_needs_migrate.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !snap.MigrateNeeded || !snap.MissingGit {
		t.Fatalf("migrate=%v git=%v", snap.MigrateNeeded, snap.MissingGit)
	}
}
