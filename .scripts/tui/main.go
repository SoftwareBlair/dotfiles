package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/engine"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/ui"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/wizard"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	dryRun := flag.Bool("dry-run", false, "start in dry-run mode")
	pkgMgr := flag.String("pkgmgr", "", "package manager (brew|apt|dnf|pacman)")
	catalogFile := flag.String("catalog", "", "load catalog JSON from file (tests / offline)")
	flag.Parse()

	setupPath, err := engine.FindSetupSh()
	if err != nil && *catalogFile == "" {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	var snap catalog.Snapshot
	if *catalogFile != "" {
		snap, err = catalog.LoadFile(*catalogFile)
	} else {
		snap, err = catalog.LoadFromSetup(setupPath, *pkgMgr, *dryRun)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load catalog: %v\n", err)
		os.Exit(1)
	}
	if *pkgMgr != "" {
		snap.PkgMgr = *pkgMgr
	}

	state := wizard.New(snap, *dryRun)
	eng := engine.Runner{SetupPath: setupPath}
	m := ui.NewModel(state, eng)

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "tui error: %v\n", err)
		os.Exit(1)
	}
	if fm, ok := final.(ui.Model); ok {
		if fm.State.Step == wizard.StepCancelled {
			os.Exit(1)
		}
		if fm.State.RunErr != "" {
			os.Exit(1)
		}
	}
}
