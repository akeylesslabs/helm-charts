package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	yaml "gopkg.in/yaml.v3"
)

// Config is the typed keyway.yaml. Defaults are applied in LoadConfig, then the
// whole struct is validated before any use (Keyway rule 2: validate-before-use,
// unknown keys rejected).
type Config struct {
	// HelmBinary is the helm executable name/path. Resolved from PATH when not
	// absolute. The nix app wires a helm wrapped with the helm-unittest plugin.
	HelmBinary string `yaml:"helmBinary"`
	// ChartsDir is the directory holding chart subdirectories (each a Chart.yaml).
	ChartsDir string `yaml:"chartsDir"`
	// Charts optionally restricts the run to an explicit subset (chart dir names
	// under ChartsDir). Empty => auto-discover every chartsDir/*/Chart.yaml.
	Charts   []string       `yaml:"charts"`
	Lint     LintConfig     `yaml:"lint"`
	Unittest UnittestConfig `yaml:"unittest"`
}

type LintConfig struct {
	Enabled *bool `yaml:"enabled"` // default true
	Strict  bool  `yaml:"strict"`  // pass `helm lint --strict`
}

type UnittestConfig struct {
	Enabled *bool `yaml:"enabled"` // default true
	// RequireTests turns a chart with no tests/ directory into a failure
	// instead of a skip — use it once every chart has a render-test suite.
	RequireTests bool `yaml:"requireTests"`
}

func boolOr(p *bool, def bool) bool {
	if p == nil {
		return def
	}
	return *p
}

func (c *Config) lintEnabled() bool     { return boolOr(c.Lint.Enabled, true) }
func (c *Config) unittestEnabled() bool { return boolOr(c.Unittest.Enabled, true) }

// LoadConfig reads + validates keyway.yaml. A missing file is NOT an error: it
// yields the zero-config defaults (helm + charts/), so the tool runs out of the
// box. Unknown keys are rejected (strict decode).
func LoadConfig(path string) (*Config, error) {
	cfg := &Config{}
	raw, err := os.ReadFile(path)
	switch {
	case os.IsNotExist(err):
		// zero-config: defaults only
	case err != nil:
		return nil, fmt.Errorf("read %s: %w", path, err)
	default:
		dec := yaml.NewDecoder(bytes.NewReader(raw))
		dec.KnownFields(true) // unknown keys => error
		if err := dec.Decode(cfg); err != nil {
			return nil, fmt.Errorf("parse %s: %w", path, err)
		}
	}
	cfg.applyDefaults()
	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

func (c *Config) applyDefaults() {
	if c.HelmBinary == "" {
		c.HelmBinary = "helm"
	}
	if c.ChartsDir == "" {
		c.ChartsDir = "charts"
	}
}

func (c *Config) validate() error {
	if c.HelmBinary == "" {
		return fmt.Errorf("keyway.yaml: helmBinary must not be empty")
	}
	fi, err := os.Stat(c.ChartsDir)
	if err != nil || !fi.IsDir() {
		return fmt.Errorf("keyway.yaml: chartsDir %q is not a directory (run from the repo root)", c.ChartsDir)
	}
	return nil
}

// DiscoverCharts returns the chart directories to act on: the explicit
// Config.Charts subset (each validated to hold a Chart.yaml) or, when empty,
// every chartsDir/*/Chart.yaml, sorted for deterministic output.
func (c *Config) DiscoverCharts() ([]string, error) {
	if len(c.Charts) > 0 {
		out := make([]string, 0, len(c.Charts))
		for _, name := range c.Charts {
			dir := filepath.Join(c.ChartsDir, name)
			if _, err := os.Stat(filepath.Join(dir, "Chart.yaml")); err != nil {
				return nil, fmt.Errorf("keyway.yaml: chart %q has no Chart.yaml at %s", name, dir)
			}
			out = append(out, dir)
		}
		return out, nil
	}
	entries, err := os.ReadDir(c.ChartsDir)
	if err != nil {
		return nil, fmt.Errorf("read chartsDir %s: %w", c.ChartsDir, err)
	}
	var out []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		dir := filepath.Join(c.ChartsDir, e.Name())
		if _, err := os.Stat(filepath.Join(dir, "Chart.yaml")); err == nil {
			out = append(out, dir)
		}
	}
	sort.Strings(out)
	if len(out) == 0 {
		return nil, fmt.Errorf("no charts found under %s", c.ChartsDir)
	}
	return out, nil
}
