package engine

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Runner executes the bash setup engine with a fixed selection.
type Runner struct {
	// SetupPath is the absolute path to setup.sh
	SetupPath string
	// Environ is an optional base environment (defaults to os.Environ).
	Environ []string
}

// Request is a non-interactive setup invocation.
type Request struct {
	PkgMgr       string
	SelectionIDs []string
	DryRun       bool
	Yes          bool
}

// Result captures stdout/stderr/exit status.
type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

// Run invokes setup.sh with YES_MODE semantics and SETUP_SELECTION_IDS.
func (r Runner) Run(req Request) (Result, error) {
	if r.SetupPath == "" {
		return Result{}, fmt.Errorf("setup path is empty")
	}
	if len(req.SelectionIDs) == 0 {
		return Result{}, fmt.Errorf("no packages selected")
	}

	args := []string{}
	if req.Yes {
		args = append(args, "-y")
	}
	if req.DryRun {
		args = append(args, "-n")
	}
	if req.PkgMgr != "" {
		args = append(args, "--pkgmgr", req.PkgMgr)
	}
	args = append(args, "--bash") // never re-enter the TUI

	cmd := exec.Command(r.SetupPath, args...)
	env := r.Environ
	if env == nil {
		env = os.Environ()
	}
	env = append(env,
		"SETUP_SELECTION_IDS="+strings.Join(req.SelectionIDs, " "),
		"DOTFILES_NO_TUI=1",
	)
	cmd.Env = env

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()

	res := Result{
		Stdout: stdout.String(),
		Stderr: stderr.String(),
	}
	if err == nil {
		return res, nil
	}
	if ee, ok := err.(*exec.ExitError); ok {
		res.ExitCode = ee.ExitCode()
		return res, fmt.Errorf("setup failed (exit %d): %s", res.ExitCode, strings.TrimSpace(res.Stderr))
	}
	return res, err
}

// FindSetupSh locates setup.sh relative to the TUI binary / module.
func FindSetupSh() (string, error) {
	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), "..", "setup.sh"))
	}
	if wd, err := os.Getwd(); err == nil {
		candidates = append(candidates,
			filepath.Join(wd, "setup.sh"),
			filepath.Join(wd, "..", "setup.sh"),
			filepath.Join(wd, ".scripts", "setup.sh"),
		)
	}
	for _, c := range candidates {
		if abs, err := filepath.Abs(c); err == nil {
			if st, err := os.Stat(abs); err == nil && !st.IsDir() {
				return abs, nil
			}
		}
	}
	return "", fmt.Errorf("could not find setup.sh")
}
