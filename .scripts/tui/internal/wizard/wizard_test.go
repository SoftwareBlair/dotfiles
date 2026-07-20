package wizard_test

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/wizard"
)

func loadNamed(t *testing.T, name string) catalog.Snapshot {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", name)
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatalf("load fixture: %v", err)
	}
	return snap
}

func TestMultiProfileStartsAtProfile(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	if st.Step != wizard.StepPkgMgr {
		// two pkgmgr options → pkgmgr first
		t.Fatalf("expected pkgmgr step, got %s", st.Step)
	}
	_ = st.Next()
	if st.Step != wizard.StepProfile {
		t.Fatalf("expected profile after pkgmgr, got %s", st.Step)
	}
}

func TestApplyBlairProfileLoadsDevAndAliases(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	// Find Blair index
	blair := -1
	for i, p := range st.Snapshot.Profiles {
		if p.ID == "SoftwareBlair" {
			blair = i
			break
		}
	}
	if blair < 0 {
		t.Fatal("blair profile missing")
	}
	st.ApplyProfile(blair)
	if st.ThemeStarship != "blair" {
		t.Fatalf("theme=%s", st.ThemeStarship)
	}
	if !st.Selected["zsh_aliases"] {
		t.Fatal("expected aliases default selected")
	}
	if !st.Selected["cursor"] {
		t.Fatal("expected cursor default selected")
	}
	if len(st.DevPackages) == 0 {
		t.Fatal("expected dev packages")
	}
}

func TestShellThenDevThenConfirm(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	st.Step = wizard.StepShellPackages
	if err := st.Next(); err != nil {
		t.Fatal(err)
	}
	if st.Step != wizard.StepDevPackages {
		t.Fatalf("got %s", st.Step)
	}
	if err := st.Next(); err != nil {
		t.Fatal(err)
	}
	if st.Step != wizard.StepConfirm {
		t.Fatalf("got %s", st.Step)
	}
}

func TestEmptySelectionBlockedAtConfirmGate(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	st.Step = wizard.StepDevPackages
	st.ClearPackages()
	for id := range st.Selected {
		st.Selected[id] = false
	}
	if err := st.Next(); err == nil {
		t.Fatal("expected error")
	}
}

func TestDryRunInSummary(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	got := strings.Join(st.SummaryLines(), "\n")
	if !strings.Contains(got, "DRY RUN") {
		t.Fatalf("missing DRY RUN:\n%s", got)
	}
	if !strings.Contains(got, "Profile:") {
		t.Fatalf("missing Profile:\n%s", got)
	}
	st.DryRun = false
	got = strings.Join(st.SummaryLines(), "\n")
	if !strings.Contains(got, "INSTALL") {
		t.Fatalf("missing INSTALL:\n%s", got)
	}
}

func TestMigrateAndPrereqFirstSteps(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_needs_migrate.json"), false)
	if st.Step != wizard.StepPrereq {
		t.Fatalf("expected prereq (missing git), got %s", st.Step)
	}
	st.PrereqIndex = 0
	if err := st.Next(); err != nil {
		t.Fatal(err)
	}
	if st.Step != wizard.StepMigrate {
		t.Fatalf("expected migrate, got %s", st.Step)
	}
	_ = st.Next()
	if st.Step != wizard.StepShellPackages {
		t.Fatalf("expected shell (single profile), got %s", st.Step)
	}
}

func TestProfilePreviewContainsPackages(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	for i, p := range st.Snapshot.Profiles {
		if p.ID == "SoftwareBlair" {
			st.ProfileIndex = i
			break
		}
	}
	prev := strings.Join(st.ProfilePreviewLines(), "\n")
	if !strings.Contains(prev, "Cursor") || !strings.Contains(prev, "Shell aliases") {
		t.Fatalf("preview missing packages:\n%s", prev)
	}
}

func TestBackNavigation(t *testing.T) {
	st := wizard.New(loadNamed(t, "catalog_default_and_blair.json"), true)
	st.Step = wizard.StepConfirm
	st.Back()
	if st.Step != wizard.StepDevPackages {
		t.Fatalf("got %s", st.Step)
	}
	st.Back()
	if st.Step != wizard.StepShellPackages {
		t.Fatalf("got %s", st.Step)
	}
}
