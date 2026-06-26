// keyway — akeylesslabs/helm-charts render-test + lint runner.
//
// Keyway tool (the akeyless tooling standard): typed YAML config validated
// before use, a typed Outcome + JSON receipt, exit codes 0/1/2, and ZERO
// shell. The only subprocess is `helm`, invoked solely via os/exec with a
// discrete argument list — never through a shell.
//
// Subcommands:
//
//	lint     — `helm lint` every (configured) chart.
//	unittest — `helm unittest` every chart that ships a tests/ suite. This is
//	           the pure-render gate: no cluster, fully deterministic.
//	ci       — lint + unittest across all charts, one aggregate JSON receipt.
//
// Exit codes (Keyway): 0 = every gate passed, 1 = a gate evaluated and failed
// (lint or render findings), 2 = the tool itself errored (bad config, helm
// binary missing, internal error). CI maps these directly; 1 and 2 are never
// collapsed.
package main

import (
	"fmt"
	"os"
)

const (
	exitOK    = 0
	exitGate  = 1
	exitError = 2
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: keyway <lint|unittest|ci> [flags]")
		os.Exit(exitError)
	}
	switch os.Args[1] {
	case "lint":
		os.Exit(cmdLint(os.Args[2:]))
	case "unittest":
		os.Exit(cmdUnittest(os.Args[2:]))
	case "ci":
		os.Exit(cmdCI(os.Args[2:]))
	case "-h", "--help", "help":
		fmt.Fprintln(os.Stderr, "usage: keyway <lint|unittest|ci> [--config keyway.yaml] [--receipt path.json]")
		os.Exit(exitOK)
	default:
		fmt.Fprintf(os.Stderr, "keyway: unknown subcommand %q\n", os.Args[1])
		os.Exit(exitError)
	}
}
