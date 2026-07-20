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
	path := filepath.Join(filepath.Dir(file), "..", "..", "testdata", "catalog_default_and_blair.json")
	snap, err := catalog.LoadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return snap
}

func TestProfilePreviewInView(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.Step = wizard.StepProfile
	for i, p := range st.Snapshot.Profiles {
		if p.ID == "SoftwareBlair" {
			st.ProfileIndex = i
			break
		}
	}
	m := ui.NewModel(st, engine.Runner{})
	view := m.View()
	if !strings.Contains(view, "Blair") || !strings.Contains(view, "Cursor") {
		t.Fatalf("view missing preview:\n%s", view)
	}
}

func TestShellThenDevViews(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.ApplyProfile(0) // default
	st.Step = wizard.StepShellPackages
	m := ui.NewModel(st, engine.Runner{})
	view := m.View()
	if !strings.Contains(view, "Shell environment") || !strings.Contains(view, "Starship") {
		t.Fatalf("shell view:\n%s", view)
	}
	m2, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = m2.(ui.Model)
	if m.State.Step != wizard.StepDevPackages {
		t.Fatalf("got %s", m.State.Step)
	}
	view = m.View()
	if !strings.Contains(view, "Developer applications") {
		t.Fatalf("dev view:\n%s", view)
	}
}

func TestSpaceTogglesSelection(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.Step = wizard.StepShellPackages
	st.PackageCursor = 0
	m := ui.NewModel(st, engine.Runner{})
	before := m.State.Selected["zsh"]
	m2, _ := m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = m2.(ui.Model)
	if m.State.Selected["zsh"] == before {
		t.Fatal("space should toggle")
	}
}

func TestConfirmShowsDryRun(t *testing.T) {
	st := wizard.New(fixture(t), true)
	st.Step = wizard.StepConfirm
	m := ui.NewModel(st, engine.Runner{})
	view := m.View()
	if !strings.Contains(view, "DRY RUN") {
		t.Fatalf("missing DRY RUN:\n%s", view)
	}
}

func TestQuitCancels(t *testing.T) {
	st := wizard.New(fixture(t), true)
	m := ui.NewModel(st, engine.Runner{})
	m2, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("q")})
	m = m2.(ui.Model)
	if m.State.Step != wizard.StepCancelled {
		t.Fatalf("expected cancelled, got %s", m.State.Step)
	}
	if cmd == nil {
		t.Fatal("expected quit cmd")
	}
}
