package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

// loadFor parses the shared --config/--receipt flags and loads the typed
// config. A nil *Config return means the caller should exit with the returned
// code (a setup/tool error).
func loadFor(command string, args []string) (*Config, string, int) {
	fs := flag.NewFlagSet(command, flag.ContinueOnError)
	cfgPath := fs.String("config", "keyway.yaml", "typed keyway config (YAML)")
	receiptPath := fs.String("receipt", "", "write a JSON receipt to this path")
	if err := fs.Parse(args); err != nil {
		return nil, "", exitError
	}
	cfg, err := LoadConfig(*cfgPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "keyway %s: %v\n", command, err)
		return nil, "", exitError
	}
	return cfg, *receiptPath, exitOK
}

func cmdLint(args []string) int {
	cfg, receipt, code := loadFor("lint", args)
	if cfg == nil {
		return code
	}
	return runGates("lint", cfg, true, false, receipt)
}

func cmdUnittest(args []string) int {
	cfg, receipt, code := loadFor("unittest", args)
	if cfg == nil {
		return code
	}
	return runGates("unittest", cfg, false, true, receipt)
}

func cmdCI(args []string) int {
	cfg, receipt, code := loadFor("ci", args)
	if cfg == nil {
		return code
	}
	return runGates("ci", cfg, cfg.lintEnabled(), cfg.unittestEnabled(), receipt)
}

// runGates is the shared engine: discover charts, run the requested steps per
// chart, aggregate into a receipt, print the summary, and map the outcome to an
// exit code (0 pass / 1 gate-failed / 2 tool-error).
func runGates(command string, cfg *Config, doLint, doUnittest bool, receiptPath string) int {
	charts, err := cfg.DiscoverCharts()
	if err != nil {
		fmt.Fprintf(os.Stderr, "keyway %s: %v\n", command, err)
		return exitError
	}
	receipt := Receipt{Tool: "keyway", Command: command}
	failed := false
	for _, dir := range charts {
		cr := ChartResult{Chart: dir}
		if doLint {
			step, toolErr := lintStep(cfg, dir)
			if toolErr != nil {
				fmt.Fprintf(os.Stderr, "keyway %s: %v\n", command, toolErr)
				return exitError
			}
			cr.Steps = append(cr.Steps, step)
		}
		if doUnittest {
			step, toolErr := unittestStep(cfg, dir)
			if toolErr != nil {
				fmt.Fprintf(os.Stderr, "keyway %s: %v\n", command, toolErr)
				return exitError
			}
			cr.Steps = append(cr.Steps, step)
		}
		receipt.Charts = append(receipt.Charts, cr)
		if cr.failed() {
			failed = true
		}
	}
	if err := finish(os.Stderr, &receipt, failed, receiptPath); err != nil {
		fmt.Fprintf(os.Stderr, "keyway %s: %v\n", command, err)
		return exitError
	}
	if failed {
		return exitGate
	}
	return exitOK
}

// lintStep runs `helm lint <chart>`. helm's own exit code is the verdict.
func lintStep(cfg *Config, dir string) (StepResult, error) {
	a := []string{"lint", dir}
	if cfg.Lint.Strict {
		a = append(a, "--strict")
	}
	out, ok, toolErr := runHelm(cfg.HelmBinary, a...)
	if toolErr != nil {
		return StepResult{}, toolErr
	}
	res := StepResult{Step: "lint", Status: StatusPass}
	if !ok {
		res.Status = StatusFail
		res.Output = trim(out)
	}
	return res, nil
}

// unittestStep runs `helm unittest <chart>` — the pure-render gate. A chart
// with no tests/ directory is SKIPPED (unless Unittest.RequireTests), never
// failed, so charts can adopt render tests incrementally.
func unittestStep(cfg *Config, dir string) (StepResult, error) {
	testsDir := filepath.Join(dir, "tests")
	if fi, err := os.Stat(testsDir); err != nil || !fi.IsDir() {
		if cfg.Unittest.RequireTests {
			return StepResult{Step: "unittest", Status: StatusFail, Detail: "no tests/ directory (requireTests=true)"}, nil
		}
		return StepResult{Step: "unittest", Status: StatusSkip, Detail: "no tests/ directory"}, nil
	}
	out, ok, toolErr := runHelm(cfg.HelmBinary, "unittest", dir)
	if toolErr != nil {
		return StepResult{}, toolErr
	}
	res := StepResult{Step: "unittest", Status: StatusPass}
	if !ok {
		res.Status = StatusFail
		res.Output = trim(out)
	}
	return res, nil
}
