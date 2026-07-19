package ui

import (
	"fmt"
	"strings"

	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/engine"
	"github.com/SoftwareBlair/dotfiles/scripts/tui/internal/wizard"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("12"))
	dimStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	okStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("10"))
	errStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("9"))
	selStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("14")).Bold(true)
	boxStyle   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(0, 1)
)

// Model is the Bubble Tea model wrapping wizard.State.
type Model struct {
	State  wizard.State
	Width  int
	Height int

	Engine   engine.Runner
	status   string
	quitting bool
}

type runFinishedMsg struct {
	output string
	err    error
}

// NewModel creates a TUI model from wizard state.
func NewModel(state wizard.State, eng engine.Runner) Model {
	return Model{State: state, Engine: eng}
}

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
		return m, nil

	case runFinishedMsg:
		m.State.FinishRun(msg.output, msg.err)
		if msg.err != nil {
			m.status = msg.err.Error()
		} else {
			m.status = "complete"
		}
		return m, nil

	case tea.KeyMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	if m.State.Step == wizard.StepRunning {
		return m, nil
	}
	if m.State.Step == wizard.StepDone || m.State.Step == wizard.StepCancelled {
		switch msg.String() {
		case "q", "esc", "enter", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		}
		return m, nil
	}

	switch msg.String() {
	case "ctrl+c", "q":
		m.State.Cancel()
		m.quitting = true
		return m, tea.Quit
	case "esc":
		if m.State.Step == wizard.StepPkgMgr || (m.State.Step == wizard.StepPackages && len(m.State.Snapshot.PkgMgrOptions) <= 1) {
			m.State.Cancel()
			m.quitting = true
			return m, tea.Quit
		}
		m.State.Back()
		m.status = ""
		return m, nil
	}

	switch m.State.Step {
	case wizard.StepPkgMgr:
		switch msg.String() {
		case "up", "k":
			m.State.MovePkgMgr(-1)
		case "down", "j":
			m.State.MovePkgMgr(1)
		case "enter", " ":
			_ = m.State.Next()
		}
	case wizard.StepPackages:
		switch msg.String() {
		case "up", "k":
			m.State.MovePackageCursor(-1)
		case "down", "j":
			m.State.MovePackageCursor(1)
		case " ":
			m.State.TogglePackage()
		case "a":
			m.State.SelectAllPackages()
		case "d":
			m.State.SelectDefaultPackages()
		case "c":
			m.State.ClearPackages()
		case "enter":
			if err := m.State.Next(); err != nil {
				m.status = err.Error()
			} else {
				m.status = ""
			}
		}
	case wizard.StepConfirm:
		switch msg.String() {
		case "n":
			m.State.DryRun = !m.State.DryRun
		case "enter":
			_ = m.State.Next()
			return m, m.runEngine()
		case "backspace":
			m.State.Back()
		}
	}
	return m, nil
}

func (m Model) runEngine() tea.Cmd {
	st := m.State
	eng := m.Engine
	return func() tea.Msg {
		res, err := eng.Run(engine.Request{
			PkgMgr:       st.PkgMgr,
			SelectionIDs: st.SelectedIDs(),
			DryRun:       st.DryRun,
			Yes:          true,
		})
		out := res.Stdout
		if res.Stderr != "" {
			out = out + "\n" + res.Stderr
		}
		return runFinishedMsg{output: out, err: err}
	}
}

func (m Model) View() string {
	if m.quitting && m.State.Step == wizard.StepCancelled {
		return dimStyle.Render("Cancelled.\n")
	}

	var b strings.Builder
	b.WriteString(titleStyle.Render("New machine setup"))
	b.WriteString("  ")
	b.WriteString(dimStyle.Render(m.State.Snapshot.PlatformLabel))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render(m.State.Snapshot.DotfilesDir))
	b.WriteString("\n\n")

	switch m.State.Step {
	case wizard.StepPkgMgr:
		b.WriteString(m.viewPkgMgr())
	case wizard.StepPackages:
		b.WriteString(m.viewPackages())
	case wizard.StepConfirm:
		b.WriteString(m.viewConfirm())
	case wizard.StepRunning:
		b.WriteString(okStyle.Render("Running setup…"))
		b.WriteString("\n")
		b.WriteString(dimStyle.Render("Please wait."))
	case wizard.StepDone:
		b.WriteString(m.viewDone())
	}

	if m.status != "" && m.State.Step != wizard.StepDone {
		b.WriteString("\n\n")
		b.WriteString(errStyle.Render(m.status))
	}

	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render(m.helpLine()))
	b.WriteString("\n")
	return b.String()
}

func (m Model) viewPkgMgr() string {
	var b strings.Builder
	b.WriteString(selStyle.Render("Package manager"))
	b.WriteString("\n\n")
	for i, opt := range m.State.Snapshot.PkgMgrOptions {
		cursor := "  "
		if i == m.State.PkgMgrIndex {
			cursor = "> "
		}
		line := cursor + opt.Label
		if i == m.State.PkgMgrIndex {
			line = selStyle.Render(line)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func (m Model) viewPackages() string {
	var b strings.Builder
	b.WriteString(selStyle.Render("Select packages"))
	b.WriteString("  ")
	b.WriteString(dimStyle.Render(fmt.Sprintf("(%s)", m.State.PkgMgr)))
	b.WriteString("\n\n")
	for i, p := range m.State.Snapshot.Packages {
		cursor := "  "
		if i == m.State.PackageCursor {
			cursor = "> "
		}
		mark := "[ ]"
		if m.State.Selected[p.ID] {
			mark = "[x]"
		}
		line := fmt.Sprintf("%s%s %s", cursor, mark, p.Name)
		if i == m.State.PackageCursor {
			line = selStyle.Render(line)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	b.WriteString("\n")
	b.WriteString(dimStyle.Render(fmt.Sprintf("%d selected", len(m.State.SelectedIDs()))))
	return b.String()
}

func (m Model) viewConfirm() string {
	var b strings.Builder
	b.WriteString(selStyle.Render("Confirm"))
	b.WriteString("\n\n")
	body := strings.Join(m.State.SummaryLines(), "\n")
	b.WriteString(boxStyle.Render(body))
	b.WriteString("\n\n")
	if m.State.DryRun {
		b.WriteString(okStyle.Render("Dry-run mode — nothing will be installed."))
	} else {
		b.WriteString(errStyle.Render("Install mode — packages and symlinks will be applied."))
	}
	b.WriteString("\n")
	b.WriteString(dimStyle.Render("Press n to toggle dry-run / install."))
	return b.String()
}

func (m Model) viewDone() string {
	var b strings.Builder
	if m.State.RunErr != "" {
		b.WriteString(errStyle.Render("Setup finished with errors"))
		b.WriteString("\n\n")
		b.WriteString(m.State.RunErr)
	} else if m.State.DryRun {
		b.WriteString(okStyle.Render("Dry run complete — no changes made."))
	} else {
		b.WriteString(okStyle.Render("Setup complete — restart your terminal."))
	}
	b.WriteString("\n\n")
	// Tail of engine output (keep view readable)
	out := strings.TrimSpace(m.State.RunOutput)
	if out != "" {
		lines := strings.Split(out, "\n")
		if len(lines) > 30 {
			lines = lines[len(lines)-30:]
		}
		b.WriteString(dimStyle.Render(strings.Join(lines, "\n")))
	}
	return b.String()
}

func (m Model) helpLine() string {
	switch m.State.Step {
	case wizard.StepPkgMgr:
		return "↑/↓ move · enter select · q quit"
	case wizard.StepPackages:
		return "↑/↓ move · space toggle · a all · d defaults · enter continue · esc back · q quit"
	case wizard.StepConfirm:
		return "enter run · n toggle dry-run · esc back · q quit"
	case wizard.StepRunning:
		return "working…"
	case wizard.StepDone:
		return "enter / q quit"
	default:
		return "q quit"
	}
}
