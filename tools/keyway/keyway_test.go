package main

import (
	"os"
	"path/filepath"
	"testing"
)

// mkChart creates chartsDir/<name>/Chart.yaml (+ optional tests/ dir) under a
// temp root and returns the chartsDir.
func mkCharts(t *testing.T, names []string, withTests map[string]bool) string {
	t.Helper()
	root := t.TempDir()
	chartsDir := filepath.Join(root, "charts")
	for _, n := range names {
		dir := filepath.Join(chartsDir, n)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "Chart.yaml"), []byte("name: "+n+"\nversion: 0.0.1\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if withTests[n] {
			if err := os.MkdirAll(filepath.Join(dir, "tests"), 0o755); err != nil {
				t.Fatal(err)
			}
		}
	}
	return chartsDir
}

func TestLoadConfigDefaultsWhenMissing(t *testing.T) {
	chartsDir := mkCharts(t, []string{"a"}, nil)
	// point default chartsDir at our temp dir via an explicit config-less load:
	// LoadConfig of a non-existent path yields defaults, then validate() checks
	// chartsDir — so we cd into the temp root so "charts" resolves.
	root := filepath.Dir(chartsDir)
	t.Chdir(root)
	cfg, err := LoadConfig("does-not-exist.yaml")
	if err != nil {
		t.Fatalf("expected zero-config defaults, got %v", err)
	}
	if cfg.HelmBinary != "helm" || cfg.ChartsDir != "charts" {
		t.Fatalf("bad defaults: %+v", cfg)
	}
	if !cfg.lintEnabled() || !cfg.unittestEnabled() {
		t.Fatal("lint/unittest should default to enabled")
	}
}

func TestLoadConfigRejectsUnknownKeys(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "charts"), 0o755); err != nil {
		t.Fatal(err)
	}
	p := filepath.Join(root, "keyway.yaml")
	if err := os.WriteFile(p, []byte("chartsDir: charts\nbogusKey: 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Chdir(root)
	if _, err := LoadConfig("keyway.yaml"); err == nil {
		t.Fatal("expected strict-decode error for unknown key, got nil")
	}
}

func TestLoadConfigRejectsMissingChartsDir(t *testing.T) {
	root := t.TempDir()
	p := filepath.Join(root, "keyway.yaml")
	if err := os.WriteFile(p, []byte("chartsDir: nope\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Chdir(root)
	if _, err := LoadConfig("keyway.yaml"); err == nil {
		t.Fatal("expected error for non-existent chartsDir, got nil")
	}
}

func TestDiscoverChartsAuto(t *testing.T) {
	chartsDir := mkCharts(t, []string{"b-chart", "a-chart"}, nil)
	cfg := &Config{HelmBinary: "helm", ChartsDir: chartsDir}
	got, err := cfg.DiscoverCharts()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || filepath.Base(got[0]) != "a-chart" || filepath.Base(got[1]) != "b-chart" {
		t.Fatalf("expected sorted [a-chart b-chart], got %v", got)
	}
}

func TestDiscoverChartsExplicitSubset(t *testing.T) {
	chartsDir := mkCharts(t, []string{"a", "b"}, nil)
	cfg := &Config{HelmBinary: "helm", ChartsDir: chartsDir, Charts: []string{"b"}}
	got, err := cfg.DiscoverCharts()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || filepath.Base(got[0]) != "b" {
		t.Fatalf("expected [b], got %v", got)
	}
	cfg.Charts = []string{"missing"}
	if _, err := cfg.DiscoverCharts(); err == nil {
		t.Fatal("expected error for missing chart, got nil")
	}
}

func TestUnittestStepSkipsWithoutTestsDir(t *testing.T) {
	chartsDir := mkCharts(t, []string{"notests"}, nil)
	cfg := &Config{HelmBinary: "helm", ChartsDir: chartsDir}
	step, err := unittestStep(cfg, filepath.Join(chartsDir, "notests"))
	if err != nil {
		t.Fatal(err)
	}
	if step.Status != StatusSkip {
		t.Fatalf("expected skip without tests/, got %q", step.Status)
	}
	cfg.Unittest.RequireTests = true
	step, _ = unittestStep(cfg, filepath.Join(chartsDir, "notests"))
	if step.Status != StatusFail {
		t.Fatalf("expected fail with requireTests, got %q", step.Status)
	}
}

func TestChartResultFailed(t *testing.T) {
	ok := ChartResult{Chart: "c", Steps: []StepResult{{Step: "lint", Status: StatusPass}, {Step: "unittest", Status: StatusSkip}}}
	if ok.failed() {
		t.Fatal("pass+skip must not be failed")
	}
	bad := ChartResult{Chart: "c", Steps: []StepResult{{Step: "unittest", Status: StatusFail}}}
	if !bad.failed() {
		t.Fatal("a fail step must make the chart failed")
	}
}
