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
	content := "#!/bin/bash\n" +
		"echo \"ARGS:$*\"\n" +
		"echo \"SELECTION:$SETUP_SELECTION_IDS\"\n" +
		"echo \"PROFILE:$SETUP_PROFILE\"\n" +
		"echo \"THEMES:$SETUP_THEMES\"\n" +
		"echo \"MIGRATE:$SETUP_MIGRATE\"\n" +
		"echo \"NO_TUI:$DOTFILES_NO_TUI\"\n"
	if err := os.WriteFile(script, []byte(content), 0o755); err != nil {
		t.Fatal(err)
	}

	r := engine.Runner{SetupPath: script, Environ: []string{"PATH=" + os.Getenv("PATH")}}
	res, err := r.Run(engine.Request{
		PkgMgr:        "apt",
		Profile:       "default",
		SelectionIDs:  []string{"zsh", "starship"},
		ThemeStarship: "stock",
		Migrate:       "upgrade",
		DryRun:        true,
		Yes:           true,
	})
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	out := res.Stdout
	if !strings.Contains(out, "ARGS:-y -n --profile default --pkgmgr apt --bash") {
		t.Fatalf("unexpected args:\n%s", out)
	}
	if !strings.Contains(out, "SELECTION:zsh starship") {
		t.Fatalf("unexpected selection:\n%s", out)
	}
	if !strings.Contains(out, "THEMES:starship=stock") {
		t.Fatalf("unexpected themes:\n%s", out)
	}
	if !strings.Contains(out, "MIGRATE:upgrade") {
		t.Fatalf("unexpected migrate:\n%s", out)
	}
}

func TestRunRequiresSelection(t *testing.T) {
	r := engine.Runner{SetupPath: "/bin/true"}
	_, err := r.Run(engine.Request{Yes: true})
	if err == nil {
		t.Fatal("expected error for empty selection")
	}
}
