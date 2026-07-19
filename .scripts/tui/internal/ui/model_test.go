package ui_test

import (
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/engine"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/ui"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/wizard"

	tea "github.com/charmbracelet/bubbletea"
)

func fixture(t *testing.T) catalog.Snapshot {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_linux_apt.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return snap
}

func key(s string) tea.KeyMsg {
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
}

func TestViewShowsPackageListAfterPkgMgr(t *testing.T) {
	st := wizard.New(fixture(t), true)
	m := ui.NewModel(st, engine.Runner{})

	// select apt (index 1) and continue
	m2, _ := m.Update(tea.KeyMsg{Type: tea.KeyDown})
	m = m2.(ui.Model)
	m2, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = m2.(ui.Model)

	if m.State.Step != wizard.StepPackages {
		t.Fatalf("expected packages step, got %s", m.State.Step)
	}
	view := m.View()
	for _, name := range []string{"SFMono Nerd Font", "Starship", "Cursor", "VS Code"} {
		if !strings.Contains(view, name) {
			t.Fatalf("view missing %q\n%s", name, view)
		}
	}
	if !strings.Contains(view, "[x]") {
		t.Fatalf("expected selected markers in view\n%s", view)
	}
}

func TestSpaceTogglesSelectionInView(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.Step = wizard.StepPackages
	st.PackageCursor = 0
	m := ui.NewModel(st, engine.Runner{})

	before := m.State.Selected["sfmono_nerd"]
	m2, _ := m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = m2.(ui.Model)
	if m.State.Selected["sfmono_nerd"] == before {
		t.Fatal("space should toggle selection")
	}
}

func TestConfirmSummaryOutput(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.Step = wizard.StepPackages
	st.PkgMgr = "apt"
	st.ClearPackages()
	st.Selected["cursor"] = true
	m := ui.NewModel(st, engine.Runner{})

	m2, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = m2.(ui.Model)
	if m.State.Step != wizard.StepConfirm {
		t.Fatalf("got %s", m.State.Step)
	}
	view := m.View()
	if !strings.Contains(view, "Package manager: apt") {
		t.Fatalf("missing pkgmgr in confirm view\n%s", view)
	}
	if !strings.Contains(view, "Cursor") {
		t.Fatalf("missing Cursor in confirm view\n%s", view)
	}
	if !strings.Contains(view, "DRY RUN") {
		t.Fatalf("missing DRY RUN in confirm view\n%s", view)
	}
}

func TestQuitCancels(t *testing.T) {
	st := wizard.New(fixture(t), true)
	m := ui.NewModel(st, engine.Runner{})
	m2, cmd := m.Update(key("q"))
	m = m2.(ui.Model)
	if m.State.Step != wizard.StepCancelled {
		t.Fatalf("expected cancelled, got %s", m.State.Step)
	}
	if cmd == nil {
		t.Fatal("expected quit cmd")
	}
}
