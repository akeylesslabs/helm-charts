package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

// Status is the per-step verdict vocabulary.
type Status string

const (
	StatusPass Status = "pass"
	StatusFail Status = "fail"
	StatusSkip Status = "skip"
)

// StepResult is one gate step (lint or unittest) for one chart.
type StepResult struct {
	Step   string `json:"step"` // "lint" | "unittest"
	Status Status `json:"status"`
	Detail string `json:"detail,omitempty"`
	Output string `json:"output,omitempty"` // captured helm output (trimmed)
}

// ChartResult aggregates a chart's step verdicts.
type ChartResult struct {
	Chart string       `json:"chart"`
	Steps []StepResult `json:"steps"`
}

func (cr ChartResult) failed() bool {
	for _, s := range cr.Steps {
		if s.Status == StatusFail {
			return true
		}
	}
	return false
}

// Receipt is the machine-readable run artifact (Keyway rule 5).
type Receipt struct {
	Tool    string        `json:"tool"`
	Command string        `json:"command"`
	Charts  []ChartResult `json:"charts"`
	Outcome string        `json:"outcome"` // "ok" | "failed"
}

// runHelm executes `helm <args...>` with NO shell — a discrete argv only. It
// returns the combined stdout+stderr, whether helm exited 0, and a non-nil
// error ONLY when helm could not be started (e.g. binary missing) — i.e. a
// genuine tool error, distinct from a non-zero gate result.
func runHelm(helmBin string, args ...string) (output string, passed bool, toolErr error) {
	cmd := exec.Command(helmBin, args...)
	var buf strings.Builder
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	err := cmd.Run()
	if err == nil {
		return buf.String(), true, nil
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		// helm ran and exited non-zero => a gate finding, not a tool error.
		return buf.String(), false, nil
	}
	// could not start the process (missing binary, permission) => tool error
	return buf.String(), false, fmt.Errorf("run %s %s: %w", helmBin, strings.Join(args, " "), err)
}

func writeReceipt(path string, r Receipt) error {
	b, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0o644)
}

// trim caps captured helm output so a receipt stays readable; the full output
// is streamed to stderr for failures by the caller.
func trim(s string) string {
	s = strings.TrimRight(s, "\n ")
	const max = 4000
	if len(s) > max {
		return s[:max] + "\n…(truncated)"
	}
	return s
}

// finish stamps the outcome, writes the receipt if requested, and prints the
// summary table.
func finish(w io.Writer, r *Receipt, failed bool, receiptPath string) error {
	if failed {
		r.Outcome = "failed"
	} else {
		r.Outcome = "ok"
	}
	printSummary(w, *r)
	if receiptPath != "" {
		if err := writeReceipt(receiptPath, *r); err != nil {
			return fmt.Errorf("receipt: %w", err)
		}
		fmt.Fprintf(w, "receipt: %s\n", receiptPath)
	}
	return nil
}

func printSummary(w io.Writer, r Receipt) {
	fmt.Fprintf(w, "\n# keyway %s — %d chart(s)\n", r.Command, len(r.Charts))
	for _, cr := range r.Charts {
		for _, s := range cr.Steps {
			mark := "ok"
			switch s.Status {
			case StatusFail:
				mark = "FAIL"
			case StatusSkip:
				mark = "skip"
			}
			line := fmt.Sprintf("  %-34s %-9s %-4s", cr.Chart, s.Step, mark)
			if s.Detail != "" {
				line += " " + s.Detail
			}
			fmt.Fprintln(w, line)
			if s.Status == StatusFail && s.Output != "" {
				for _, ln := range strings.Split(s.Output, "\n") {
					fmt.Fprintf(w, "      | %s\n", ln)
				}
			}
		}
	}
	fmt.Fprintf(w, "outcome: %s\n", r.Outcome)
}
