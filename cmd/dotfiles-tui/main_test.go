package main

import "testing"

func TestDifferentiatedConfirmationSequence(t *testing.T) {
	m := model{apps: []application{
		{id: "exact", label: "Exact", outcome: remove},
		{id: "forced", label: "Forced", outcome: force},
	}}
	m.beginConfirmation()
	want := []string{"Forced", "REMOVE 1", "FORCE REMOVE 1"}
	for index, expected := range want {
		if got := m.expectedPhrase(); got != expected {
			t.Fatalf("step %d: expected %q, got %q", index, expected, got)
		}
		m.arm++
	}
	if m.confirmationStepCount() != len(want) {
		t.Fatalf("expected %d confirmation steps, got %d", len(want), m.confirmationStepCount())
	}
}

func TestRetainedDependentBlocksPrerequisiteRemoval(t *testing.T) {
	m := model{
		apps: []application{
			{id: "runtime", label: "Runtime", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
			{id: "client", label: "Client", presence: "present", policy: "optional", exact: "enabled", outcome: leave},
		},
		dependencies: map[string][]string{"client": {"runtime"}},
	}
	m.setSelectedOutcome(remove)
	if m.apps[0].outcome != ensure {
		t.Fatalf("retained dependent must keep prerequisite ensured, got %s", m.apps[0].outcome)
	}
	if m.notice == "" {
		t.Fatal("expected a visible disabled-removal reason")
	}
}
