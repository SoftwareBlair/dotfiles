package wizard

import (
	"fmt"
	"strings"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
)

// Step is the current screen in the TUI flow.
type Step int

const (
	StepPkgMgr Step = iota
	StepPackages
	StepConfirm
	StepRunning
	StepDone
	StepCancelled
)

func (s Step) String() string {
	switch s {
	case StepPkgMgr:
		return "pkgmgr"
	case StepPackages:
		return "packages"
	case StepConfirm:
		return "confirm"
	case StepRunning:
		return "running"
	case StepDone:
		return "done"
	case StepCancelled:
		return "cancelled"
	default:
		return "unknown"
	}
}

// State is the pure wizard state machine (no Bubble Tea dependency).
type State struct {
	Snapshot catalog.Snapshot

	Step Step

	PkgMgrIndex int
	PkgMgr      string

	// Cursor / selection on the packages screen
	PackageCursor int
	Selected      map[string]bool

	DryRun bool

	// Status after run
	RunOutput string
	RunErr    string
}

// New builds initial state from a catalog snapshot.
func New(snap catalog.Snapshot, dryRun bool) State {
	selected := make(map[string]bool)
	for _, p := range snap.Packages {
		if p.Default {
			selected[p.ID] = true
		}
	}

	pkgMgr := snap.PkgMgr
	pkgMgrIndex := 0
	found := false
	for i, opt := range snap.PkgMgrOptions {
		if opt.ID == snap.PkgMgr {
			pkgMgr = opt.ID
			pkgMgrIndex = i
			found = true
			break
		}
	}
	if !found {
		for i, opt := range snap.PkgMgrOptions {
			if opt.Default {
				pkgMgr = opt.ID
				pkgMgrIndex = i
				break
			}
		}
	}
	if len(snap.PkgMgrOptions) > 0 && pkgMgr == "" {
		pkgMgr = snap.PkgMgrOptions[pkgMgrIndex].ID
	}

	start := StepPackages
	if len(snap.PkgMgrOptions) > 1 {
		start = StepPkgMgr
	}

	return State{
		Snapshot:      snap,
		Step:          start,
		PkgMgrIndex:   pkgMgrIndex,
		PkgMgr:        pkgMgr,
		PackageCursor: 0,
		Selected:      selected,
		DryRun:        dryRun || snap.DryRun,
	}
}

// SelectedIDs returns selected package IDs in catalog order.
func (s State) SelectedIDs() []string {
	ids := make([]string, 0, len(s.Selected))
	for _, p := range s.Snapshot.Packages {
		if s.Selected[p.ID] {
			ids = append(ids, p.ID)
		}
	}
	return ids
}

// SelectedNames returns display names for the confirm screen.
func (s State) SelectedNames() []string {
	names := make([]string, 0, len(s.Selected))
	for _, p := range s.Snapshot.Packages {
		if s.Selected[p.ID] {
			names = append(names, p.Name)
		}
	}
	return names
}

// SelectionCSV is a space-separated ID list for SETUP_SELECTION_IDS.
func (s State) SelectionCSV() string {
	return strings.Join(s.SelectedIDs(), " ")
}

// TogglePackage toggles selection at the current cursor.
func (s *State) TogglePackage() {
	if s.Step != StepPackages || len(s.Snapshot.Packages) == 0 {
		return
	}
	id := s.Snapshot.Packages[s.PackageCursor].ID
	s.Selected[id] = !s.Selected[id]
}

// MovePackageCursor moves the highlight on the packages list.
func (s *State) MovePackageCursor(delta int) {
	n := len(s.Snapshot.Packages)
	if n == 0 {
		return
	}
	s.PackageCursor = (s.PackageCursor + delta%n + n) % n
}

// MovePkgMgr moves the package-manager cursor.
func (s *State) MovePkgMgr(delta int) {
	n := len(s.Snapshot.PkgMgrOptions)
	if n == 0 {
		return
	}
	s.PkgMgrIndex = (s.PkgMgrIndex + delta%n + n) % n
	s.PkgMgr = s.Snapshot.PkgMgrOptions[s.PkgMgrIndex].ID
}

// SelectAllPackages marks every package selected.
func (s *State) SelectAllPackages() {
	for _, p := range s.Snapshot.Packages {
		s.Selected[p.ID] = true
	}
}

// SelectDefaultPackages restores MY_SETUP defaults.
func (s *State) SelectDefaultPackages() {
	for _, p := range s.Snapshot.Packages {
		s.Selected[p.ID] = p.Default
	}
}

// ClearPackages deselects everything.
func (s *State) ClearPackages() {
	for _, p := range s.Snapshot.Packages {
		s.Selected[p.ID] = false
	}
}

// Next advances to the next step when valid.
func (s *State) Next() error {
	switch s.Step {
	case StepPkgMgr:
		if len(s.Snapshot.PkgMgrOptions) > 0 {
			s.PkgMgr = s.Snapshot.PkgMgrOptions[s.PkgMgrIndex].ID
		}
		s.Step = StepPackages
	case StepPackages:
		if len(s.SelectedIDs()) == 0 {
			return fmt.Errorf("select at least one package")
		}
		s.Step = StepConfirm
	case StepConfirm:
		s.Step = StepRunning
	default:
		return fmt.Errorf("cannot advance from %s", s.Step)
	}
	return nil
}

// Back returns to the previous step.
func (s *State) Back() {
	switch s.Step {
	case StepPackages:
		if len(s.Snapshot.PkgMgrOptions) > 1 {
			s.Step = StepPkgMgr
		}
	case StepConfirm:
		s.Step = StepPackages
	}
}

// Cancel marks the wizard cancelled.
func (s *State) Cancel() {
	s.Step = StepCancelled
}

// FinishRun records engine output and moves to done.
func (s *State) FinishRun(output string, err error) {
	s.RunOutput = output
	if err != nil {
		s.RunErr = err.Error()
	}
	s.Step = StepDone
}

// SummaryLines is a stable text summary for tests / confirm view.
func (s State) SummaryLines() []string {
	lines := []string{
		"New machine setup",
		fmt.Sprintf("Platform: %s", s.Snapshot.PlatformLabel),
		fmt.Sprintf("Package manager: %s", s.PkgMgr),
		fmt.Sprintf("Mode: %s", map[bool]string{true: "DRY RUN", false: "INSTALL"}[s.DryRun]),
		"Selected packages:",
	}
	for _, name := range s.SelectedNames() {
		lines = append(lines, "  • "+name)
	}
	if len(s.SelectedNames()) == 0 {
		lines = append(lines, "  (none)")
	}
	return lines
}
