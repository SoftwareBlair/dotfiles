package wizard

import (
	"fmt"
	"strings"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/catalog"
)

// Step is the current screen in the TUI flow.
type Step int

const (
	StepPrereq Step = iota
	StepPkgMgr
	StepMigrate
	StepProfile
	StepShellPackages
	StepDevPackages
	StepConfirm
	StepRunning
	StepDone
	StepCancelled
)

func (s Step) String() string {
	switch s {
	case StepPrereq:
		return "prereq"
	case StepPkgMgr:
		return "pkgmgr"
	case StepMigrate:
		return "migrate"
	case StepProfile:
		return "profile"
	case StepShellPackages:
		return "shell"
	case StepDevPackages:
		return "dev"
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

// MigrateAction is the user's migration choice.
type MigrateAction string

const (
	MigrateNone    MigrateAction = "none"
	MigrateUpgrade MigrateAction = "upgrade"
	MigrateAdopt   MigrateAction = "adopt"
	MigrateSkip    MigrateAction = "skip"
)

// State is the pure wizard state machine (no Bubble Tea dependency).
type State struct {
	Snapshot catalog.Snapshot

	Step Step

	PrereqInstall bool // user chose to install missing git/curl
	PrereqIndex   int

	PkgMgrIndex int
	PkgMgr      string

	MigrateIndex  int
	MigrateAction MigrateAction

	ProfileIndex int
	ProfileID    string
	ThemeStarship string

	PackageCursor int
	Selected      map[string]bool

	// Which list the cursor applies to
	ShellPackages []catalog.Package
	DevPackages   []catalog.Package

	DryRun bool

	RunOutput string
	RunErr    string
}

// New builds initial state from a catalog snapshot.
func New(snap catalog.Snapshot, dryRun bool) State {
	profileIndex := 0
	profileID := snap.ActiveProfile
	theme := snap.ThemeStarship
	if theme == "" {
		theme = "stock"
	}
	for i, p := range snap.Profiles {
		if p.Default || p.ID == snap.ActiveProfile {
			profileIndex = i
			profileID = p.ID
			if p.ThemeStarship != "" {
				theme = p.ThemeStarship
			}
			break
		}
	}
	if profileID == "" && len(snap.Profiles) > 0 {
		profileID = snap.Profiles[0].ID
		profileIndex = 0
	}

	packages := snap.Packages
	for _, p := range snap.Profiles {
		if p.ID == profileID && len(p.Packages) > 0 {
			packages = p.Packages
			snap.Packages = packages
			snap.ActiveProfile = profileID
			snap.ProfileName = p.Name
			snap.ProfileDescription = p.Description
			if p.ThemeStarship != "" {
				theme = p.ThemeStarship
				snap.ThemeStarship = theme
			}
			break
		}
	}

	selected := make(map[string]bool)
	for _, p := range packages {
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

	st := State{
		Snapshot:      snap,
		PrereqInstall: true,
		PkgMgrIndex:   pkgMgrIndex,
		PkgMgr:        pkgMgr,
		MigrateAction: MigrateUpgrade,
		ProfileIndex:  profileIndex,
		ProfileID:     profileID,
		ThemeStarship: theme,
		Selected:      selected,
		DryRun:        dryRun || snap.DryRun,
	}
	st.refreshPackageLists()
	st.Step = st.firstStep()
	return st
}

func (s *State) refreshPackageLists() {
	s.ShellPackages = nil
	s.DevPackages = nil
	for _, p := range s.Snapshot.Packages {
		switch {
		case p.Group == "shell":
			s.ShellPackages = append(s.ShellPackages, p)
		case p.Group == "dev":
			s.DevPackages = append(s.DevPackages, p)
		case p.Category == "shells" || p.Category == "shell-configs":
			s.ShellPackages = append(s.ShellPackages, p)
		default:
			s.DevPackages = append(s.DevPackages, p)
		}
	}
}

func (s State) needsPrereq() bool {
	return s.Snapshot.MissingGit || s.Snapshot.MissingCurl
}

func (s State) firstStep() Step {
	if s.needsPrereq() {
		return StepPrereq
	}
	if len(s.Snapshot.PkgMgrOptions) > 1 {
		return StepPkgMgr
	}
	if s.Snapshot.MigrateNeeded {
		return StepMigrate
	}
	if len(s.Snapshot.Profiles) > 1 {
		return StepProfile
	}
	return StepShellPackages
}

// FirstVisibleStep is the initial step for this snapshot (used by UI esc handling).
func (s State) FirstVisibleStep() Step {
	return s.firstStep()
}

// SelectedIDs returns all selected package IDs (shell then dev order).
func (s State) SelectedIDs() []string {
	ids := make([]string, 0, len(s.Selected))
	for _, p := range s.ShellPackages {
		if s.Selected[p.ID] {
			ids = append(ids, p.ID)
		}
	}
	for _, p := range s.DevPackages {
		if s.Selected[p.ID] {
			ids = append(ids, p.ID)
		}
	}
	return ids
}

func (s State) currentList() []catalog.Package {
	switch s.Step {
	case StepShellPackages:
		return s.ShellPackages
	case StepDevPackages:
		return s.DevPackages
	default:
		return s.Snapshot.Packages
	}
}

// ApplyProfile switches the active profile and resets package defaults.
func (s *State) ApplyProfile(index int) {
	if index < 0 || index >= len(s.Snapshot.Profiles) {
		return
	}
	p := s.Snapshot.Profiles[index]
	s.ProfileIndex = index
	s.ProfileID = p.ID
	s.Snapshot.ActiveProfile = p.ID
	s.Snapshot.ProfileName = p.Name
	s.Snapshot.ProfileDescription = p.Description
	if p.ThemeStarship != "" {
		s.ThemeStarship = p.ThemeStarship
		s.Snapshot.ThemeStarship = p.ThemeStarship
	}
	if len(p.Packages) > 0 {
		s.Snapshot.Packages = p.Packages
	}
	s.refreshPackageLists()
	s.PackageCursor = 0
	s.Selected = make(map[string]bool)
	for _, pkg := range s.Snapshot.Packages {
		if pkg.Default {
			s.Selected[pkg.ID] = true
		}
	}
}

func (s *State) TogglePackage() {
	list := s.currentList()
	if len(list) == 0 {
		return
	}
	if s.PackageCursor < 0 || s.PackageCursor >= len(list) {
		return
	}
	id := list[s.PackageCursor].ID
	s.Selected[id] = !s.Selected[id]
}

func (s *State) MovePackageCursor(delta int) {
	n := len(s.currentList())
	if n == 0 {
		return
	}
	s.PackageCursor = (s.PackageCursor + delta%n + n) % n
}

func (s *State) MovePkgMgr(delta int) {
	n := len(s.Snapshot.PkgMgrOptions)
	if n == 0 {
		return
	}
	s.PkgMgrIndex = (s.PkgMgrIndex + delta%n + n) % n
	s.PkgMgr = s.Snapshot.PkgMgrOptions[s.PkgMgrIndex].ID
}

func (s *State) MoveProfile(delta int) {
	n := len(s.Snapshot.Profiles)
	if n == 0 {
		return
	}
	s.ProfileIndex = (s.ProfileIndex + delta%n + n) % n
}

func (s *State) MoveMigrate(delta int) {
	s.MigrateIndex = (s.MigrateIndex + delta%3 + 3) % 3
}

func (s *State) MovePrereq(delta int) {
	s.PrereqIndex = (s.PrereqIndex + delta%2 + 2) % 2
}

func (s *State) SelectAllPackages() {
	for _, p := range s.currentList() {
		s.Selected[p.ID] = true
	}
}

func (s *State) SelectDefaultPackages() {
	for _, p := range s.currentList() {
		s.Selected[p.ID] = p.Default
	}
}

func (s *State) ClearPackages() {
	for _, p := range s.currentList() {
		s.Selected[p.ID] = false
	}
}

func (s *State) Next() error {
	switch s.Step {
	case StepPrereq:
		s.PrereqInstall = s.PrereqIndex == 0
		if !s.PrereqInstall && s.needsPrereq() {
			return fmt.Errorf("git and curl are required")
		}
		if len(s.Snapshot.PkgMgrOptions) > 1 {
			s.Step = StepPkgMgr
		} else if s.Snapshot.MigrateNeeded {
			s.Step = StepMigrate
		} else if len(s.Snapshot.Profiles) > 1 {
			s.Step = StepProfile
		} else {
			s.Step = StepShellPackages
		}
	case StepPkgMgr:
		if len(s.Snapshot.PkgMgrOptions) > 0 {
			s.PkgMgr = s.Snapshot.PkgMgrOptions[s.PkgMgrIndex].ID
		}
		if s.Snapshot.MigrateNeeded {
			s.Step = StepMigrate
		} else if len(s.Snapshot.Profiles) > 1 {
			s.Step = StepProfile
		} else {
			s.Step = StepShellPackages
			s.PackageCursor = 0
		}
	case StepMigrate:
		switch s.MigrateIndex {
		case 1:
			s.MigrateAction = MigrateAdopt
		case 2:
			s.MigrateAction = MigrateSkip
		default:
			s.MigrateAction = MigrateUpgrade
		}
		if len(s.Snapshot.Profiles) > 1 {
			s.Step = StepProfile
		} else {
			s.Step = StepShellPackages
			s.PackageCursor = 0
		}
	case StepProfile:
		s.ApplyProfile(s.ProfileIndex)
		s.Step = StepShellPackages
		s.PackageCursor = 0
	case StepShellPackages:
		s.Step = StepDevPackages
		s.PackageCursor = 0
	case StepDevPackages:
		if len(s.SelectedIDs()) == 0 {
			return fmt.Errorf("select at least one package or module")
		}
		s.Step = StepConfirm
	case StepConfirm:
		s.Step = StepRunning
	default:
		return fmt.Errorf("cannot advance from %s", s.Step)
	}
	return nil
}

func (s *State) Back() {
	switch s.Step {
	case StepPkgMgr:
		if s.needsPrereq() {
			s.Step = StepPrereq
		}
	case StepMigrate:
		if len(s.Snapshot.PkgMgrOptions) > 1 {
			s.Step = StepPkgMgr
		} else if s.needsPrereq() {
			s.Step = StepPrereq
		}
	case StepProfile:
		if s.Snapshot.MigrateNeeded {
			s.Step = StepMigrate
		} else if len(s.Snapshot.PkgMgrOptions) > 1 {
			s.Step = StepPkgMgr
		} else if s.needsPrereq() {
			s.Step = StepPrereq
		}
	case StepShellPackages:
		if len(s.Snapshot.Profiles) > 1 {
			s.Step = StepProfile
		} else if s.Snapshot.MigrateNeeded {
			s.Step = StepMigrate
		} else if len(s.Snapshot.PkgMgrOptions) > 1 {
			s.Step = StepPkgMgr
		} else if s.needsPrereq() {
			s.Step = StepPrereq
		}
	case StepDevPackages:
		s.Step = StepShellPackages
		s.PackageCursor = 0
	case StepConfirm:
		s.Step = StepDevPackages
		s.PackageCursor = 0
	}
}

func (s *State) Cancel() {
	s.Step = StepCancelled
}

func (s *State) FinishRun(output string, err error) {
	s.RunOutput = output
	if err != nil {
		s.RunErr = err.Error()
	}
	s.Step = StepDone
}

func (s State) ProfilePreviewLines() []string {
	if s.ProfileIndex < 0 || s.ProfileIndex >= len(s.Snapshot.Profiles) {
		return nil
	}
	p := s.Snapshot.Profiles[s.ProfileIndex]
	lines := []string{
		fmt.Sprintf("%s (@%s)", p.Name, p.ID),
		p.Description,
		fmt.Sprintf("Theme: starship=%s", p.ThemeStarship),
		"Shell:",
	}
	for _, pkg := range p.Packages {
		if pkg.Group == "shell" || pkg.Category == "shells" || pkg.Category == "shell-configs" {
			lines = append(lines, "  • "+pkg.Name)
		}
	}
	lines = append(lines, "Dev:")
	for _, pkg := range p.Packages {
		if pkg.Group == "dev" || (pkg.Group != "shell" && pkg.Category != "shells" && pkg.Category != "shell-configs") {
			lines = append(lines, "  • "+pkg.Name)
		}
	}
	return lines
}

func (s State) SummaryLines() []string {
	profileLabel := s.ProfileID
	if s.Snapshot.ProfileName != "" {
		profileLabel = fmt.Sprintf("%s (@%s)", s.Snapshot.ProfileName, s.ProfileID)
	}
	lines := []string{
		"New machine setup",
		fmt.Sprintf("Platform: %s", s.Snapshot.PlatformLabel),
		fmt.Sprintf("Profile: %s", profileLabel),
		fmt.Sprintf("Theme: starship=%s", s.ThemeStarship),
		fmt.Sprintf("Package manager: %s", s.PkgMgr),
		fmt.Sprintf("Mode: %s", map[bool]string{true: "DRY RUN", false: "INSTALL"}[s.DryRun]),
	}
	if s.MigrateAction != MigrateNone && s.MigrateAction != "" {
		lines = append(lines, fmt.Sprintf("Migrate: %s", s.MigrateAction))
	}
	lines = append(lines, "Shell / modules:")
	any := false
	for _, p := range s.ShellPackages {
		if s.Selected[p.ID] {
			any = true
			tag := ""
			if p.GenerateOnly {
				tag = " [generate]"
			}
			lines = append(lines, "  • "+p.Name+tag)
		}
	}
	if !any {
		lines = append(lines, "  (none)")
	}
	lines = append(lines, "Developer apps:")
	any = false
	for _, p := range s.DevPackages {
		if s.Selected[p.ID] {
			any = true
			lines = append(lines, "  • "+p.Name)
		}
	}
	if !any {
		lines = append(lines, "  (none)")
	}
	return lines
}

// SelectionCSV is a space-separated ID list for SETUP_SELECTION_IDS.
func (s State) SelectionCSV() string {
	return strings.Join(s.SelectedIDs(), " ")
}
