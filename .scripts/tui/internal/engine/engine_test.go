package engine_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/engine"
)

func TestRunPassesSelectionAndFlags(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "setup.sh")
	// Fake setup.sh echoes its env/args for assertions
	content := "#!/bin/bash\n" +
		"echo \"ARGS:$*\"\n" +
		"echo \"SELECTION:$SETUP_SELECTION_IDS\"\n" +
		"echo \"NO_TUI:$DOTFILES_NO_TUI\"\n"
	if err := os.WriteFile(script, []byte(content), 0o755); err != nil {
		t.Fatal(err)
	}

	r := engine.Runner{SetupPath: script, Environ: []string{"PATH=" + os.Getenv("PATH")}}
	res, err := r.Run(engine.Request{
		PkgMgr:       "apt",
		Profile:      "SoftwareBlair",
		SelectionIDs: []string{"cursor", "starship"},
		DryRun:       true,
		Yes:          true,
	})
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	out := res.Stdout
	if !strings.Contains(out, "ARGS:-y -n --profile SoftwareBlair --pkgmgr apt --bash") {
		t.Fatalf("unexpected args line:\n%s", out)
	}
	if !strings.Contains(out, "SELECTION:cursor starship") {
		t.Fatalf("unexpected selection:\n%s", out)
	}
	if !strings.Contains(out, "NO_TUI:1") {
		t.Fatalf("expected DOTFILES_NO_TUI:\n%s", out)
	}
}

func TestRunRequiresSelection(t *testing.T) {
	r := engine.Runner{SetupPath: "/bin/true"}
	_, err := r.Run(engine.Request{Yes: true})
	if err == nil {
		t.Fatal("expected error for empty selection")
	}
}
