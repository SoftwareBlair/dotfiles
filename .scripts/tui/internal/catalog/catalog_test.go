package catalog_test

import (
	"path/filepath"
	"runtime"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
)

func TestParseFixture(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_linux_apt.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if snap.PkgMgr != "apt" {
		t.Fatalf("pkgmgr=%s", snap.PkgMgr)
	}
	if len(snap.Packages) != 5 {
		t.Fatalf("packages=%d", len(snap.Packages))
	}
	if snap.Packages[0].ID != "sfmono_nerd" || !snap.Packages[0].Default {
		t.Fatalf("unexpected first package: %+v", snap.Packages[0])
	}
	if len(snap.PkgMgrOptions) != 2 {
		t.Fatalf("pkgmgr options=%d", len(snap.PkgMgrOptions))
	}
}
