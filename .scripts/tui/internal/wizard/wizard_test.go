package wizard_test

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/wizard"
)

func loadFixture(t *testing.T) catalog.Snapshot {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_linux_apt.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatalf("load fixture: %v", err)
	}
	return snap
}

func TestNewDefaultsSelected(t *testing.T) {
	st := wizard.New(loadFixture(t), true)
	if !st.DryRun {
		t.Fatal("expected dry-run")
	}
	if st.Step != wizard.StepPkgMgr {
		t.Fatalf("expected pkgmgr step, got %s", st.Step)
	}
	ids := st.SelectedIDs()
	if len(ids) != 5 {
		t.Fatalf("expected 5 defaults, got %v", ids)
	}
	if st.SelectionCSV() != "sfmono_nerd starship eza cursor vscode" {
		t.Fatalf("unexpected selection csv: %q", st.SelectionCSV())
	}
}

func TestToggleAndClear(t *testing.T) {
	st := wizard.New(loadFixture(t), true)
	st.Step = wizard.StepPackages
	st.PackageCursor = 0
	st.TogglePackage() // deselect sfmono
	if st.Selected["sfmono_nerd"] {
		t.Fatal("expected sfmono deselected")
	}
	st.ClearPackages()
	if len(st.SelectedIDs()) != 0 {
		t.Fatalf("expected empty, got %v", st.SelectedIDs())
	}
	if err := st.Next(); err == nil {
		t.Fatal("expected error advancing with empty selection")
	}
	st.SelectDefaultPackages()
	if err := st.Next(); err != nil {
		t.Fatalf("next: %v", err)
	}
	if st.Step != wizard.StepConfirm {
		t.Fatalf("expected confirm, got %s", st.Step)
	}
}

func TestPkgMgrNavigation(t *testing.T) {
	st := wizard.New(loadFixture(t), false)
	// Fixture pkgmgr is apt; New should prefer matching option
	if st.PkgMgr != "apt" {
		t.Fatalf("expected apt, got %s", st.PkgMgr)
	}
	st.MovePkgMgr(1) // wrap or move
	st.MovePkgMgr(-1)
	if st.PkgMgr != "apt" {
		t.Fatalf("expected back to apt, got %s", st.PkgMgr)
	}
	_ = st.Next()
	if st.Step != wizard.StepPackages {
		t.Fatalf("expected packages, got %s", st.Step)
	}
}

func TestSummaryLinesStable(t *testing.T) {
	st := wizard.New(loadFixture(t), true)
	st.PkgMgr = "apt"
	st.ClearPackages()
	st.Selected["cursor"] = true
	st.Selected["starship"] = true

	got := strings.Join(st.SummaryLines(), "\n")
	want := strings.TrimSpace(`
New machine setup
Platform: Linux · ubuntu · amd64
Profile: Blair (@SoftwareBlair)
Package manager: apt
Mode: DRY RUN
Selected packages:
  • Starship
  • Cursor
`)
	if got != want {
		t.Fatalf("summary mismatch\nwant:\n%s\n\ngot:\n%s", want, got)
	}
}

func TestFlowConfirmToRunning(t *testing.T) {
	st := wizard.New(loadFixture(t), true)
	st.Step = wizard.StepConfirm
	if err := st.Next(); err != nil {
		t.Fatal(err)
	}
	if st.Step != wizard.StepRunning {
		t.Fatalf("got %s", st.Step)
	}
	st.FinishRun("ok plan", nil)
	if st.Step != wizard.StepDone || st.RunOutput != "ok plan" {
		t.Fatalf("finish run failed: %+v", st)
	}
}
