package main

import (
	"fmt"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
)

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

func TestPlanningViewFitsTerminalAndKeepsSelectionVisible(t *testing.T) {
	apps := make([]application, 20)
	for i := range apps {
		apps[i] = application{
			id: fmt.Sprintf("app-%02d", i+1), label: fmt.Sprintf("Application %02d", i+1),
			group: "tools", presence: "present", custody: "managed", policy: "optional",
			exact: "enabled", force: "disabled", evidence: "registered by package manager", outcome: ensure,
		}
	}
	m := model{apps: apps, dependencies: map[string][]string{}, display: plain, stage: "select", chooseOnly: true, cursor: 19}
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	view := updated.(model).render()
	lines := strings.Split(strings.TrimSuffix(view, "\n"), "\n")
	if len(lines) > 24 {
		t.Fatalf("80x24 terminal received %d rendered lines", len(lines))
	}
	for number, line := range lines {
		if len([]rune(line)) > 80 {
			t.Fatalf("line %d is wider than the terminal: %d cells", number+1, len([]rune(line)))
		}
	}
	if !strings.Contains(view, "Application 20") {
		t.Fatal("selected application must remain visible in the scrollable lane")
	}
	for _, required := range []string{"[PLAN]", "REVIEW", "RUN", "Ensure", "Leave", "Remove", "Force", "Application 20 · present", "enter review", "q quit"} {
		if !strings.Contains(view, required) {
			t.Fatalf("planning view is missing persistent context or control %q", required)
		}
	}
}

func TestCompactStateTransitionsDescribeOnlyRealChanges(t *testing.T) {
	cases := []struct {
		name     string
		app      application
		contains string
		excludes string
	}{
		{name: "removal", app: application{label: "Managed app", presence: "present", outcome: remove}, contains: "present -> removed"},
		{name: "already absent", app: application{label: "Absent app", presence: "absent", outcome: remove}, contains: "Absent app · absent", excludes: "->"},
		{name: "ensure partial", app: application{label: "Partial app", presence: "partial", outcome: ensure}, contains: "partial -> present"},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			m := model{apps: []application{test.app}, display: plain, stage: "select", lane: laneIndex(test.app.outcome), dependencies: map[string][]string{}, width: 80, height: 20}
			view := m.render()
			if !strings.Contains(view, test.contains) {
				t.Fatalf("compact view is missing %q:\n%s", test.contains, view)
			}
			if test.excludes != "" {
				line := nextLineContaining(view, test.app.label)
				if strings.Contains(line, test.excludes) {
					t.Fatalf("compact row %q unexpectedly contains %q", line, test.excludes)
				}
			}
		})
	}
}

func nextLineContaining(content, value string) string {
	for _, line := range strings.Split(content, "\n") {
		if strings.Contains(line, value) {
			return line
		}
	}
	return ""
}

func TestASCIIFallbackRemainsASCIIWhileScrolling(t *testing.T) {
	apps := make([]application, 10)
	for i := range apps {
		apps[i] = application{id: fmt.Sprintf("app-%d", i), label: fmt.Sprintf("Application %d", i), group: "tools", presence: "present", custody: "managed", evidence: "package registration", outcome: ensure}
	}
	for _, m := range []model{
		{apps: apps, display: ascii, stage: "select", cursor: 9},
		{apps: apps, display: ascii, stage: "review", chooseOnly: true, reviewScroll: 1 << 20},
	} {
		updated, _ := m.Update(tea.WindowSizeMsg{Width: 70, Height: 16})
		for _, character := range updated.(model).render() {
			if character > 127 {
				t.Fatalf("ASCII fallback rendered non-ASCII character %q", character)
			}
		}
	}
}

func TestTinyTerminalKeepsStageAndLaneContextVisible(t *testing.T) {
	m := model{apps: []application{{id: "app", label: "App", group: "tools", outcome: ensure}}, display: ascii, stage: "select"}
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 24, Height: 8})
	view := updated.(model).render()
	lines := strings.Split(strings.TrimSuffix(view, "\n"), "\n")
	if len(lines) > 8 {
		t.Fatalf("24x8 terminal received %d rendered lines", len(lines))
	}
	for _, line := range lines {
		if len([]rune(line)) > 24 {
			t.Fatalf("tiny-terminal line exceeds width: %q", line)
		}
	}
	for _, required := range []string{"[PLAN]", "REVIEW", "RUN", "Ensure", "Leave", "Remove", "Force", "Resize"} {
		if !strings.Contains(view, required) {
			t.Fatalf("tiny-terminal fallback is missing %q", required)
		}
	}
}

func TestReviewFitsTerminalAndScrollsToLastApplication(t *testing.T) {
	apps := make([]application, 18)
	for i := range apps {
		apps[i] = application{id: fmt.Sprintf("app-%02d", i+1), label: fmt.Sprintf("Application %02d", i+1), presence: "present", custody: "managed", evidence: "review evidence", outcome: ensure}
	}
	m := model{apps: apps, display: plain, stage: "review", chooseOnly: true, reviewScroll: 1 << 20}
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 60, Height: 18})
	view := updated.(model).render()
	if lines := strings.Count(strings.TrimSuffix(view, "\n"), "\n") + 1; lines > 18 {
		t.Fatalf("60x18 review received %d rendered lines", lines)
	}
	for _, required := range []string{"PLAN", "[REVIEW]", "RUN", "Ensure", "Leave", "Remove", "Force", "Application 18", "enter accept", "choices esc back"} {
		if !strings.Contains(view, required) {
			t.Fatalf("scrolled review is missing %q:\n%s", required, view)
		}
	}
}

func TestGroupOutcomeChangesSpecificGroupOnly(t *testing.T) {
	m := model{apps: []application{
		{id: "game.one", label: "Game one", group: "gaming", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
		{id: "game.two", label: "Game two", group: "gaming", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
		{id: "editor", label: "Editor", group: "editors", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
	}, dependencies: map[string][]string{}, groupFilter: 1}
	m.setGroupOutcome(remove)
	if m.apps[0].outcome != remove || m.apps[1].outcome != remove || m.apps[2].outcome != ensure {
		t.Fatalf("group action changed the wrong outcomes: %#v", m.apps)
	}
	if !strings.Contains(m.notice, "2 set to Remove") {
		t.Fatalf("group action did not report its result: %q", m.notice)
	}
	m.groupFilter = 0
	m.setGroupOutcome(force)
	if !strings.Contains(m.notice, "Choose a specific group") {
		t.Fatalf("all-groups bulk action should be rejected, got %q", m.notice)
	}
}

func TestVerboseKeyTogglesDetailWithoutLosingNavigation(t *testing.T) {
	for _, stage := range []string{"select", "review"} {
		m := model{apps: []application{{id: "app", label: "App", outcome: ensure}}, stage: stage, lane: 2, cursor: 4, groupFilter: 1, reviewScroll: 7}
		updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "v", Code: 'v'}))
		result := updated.(model)
		if !result.verbose {
			t.Fatalf("v did not enable verbose mode during %s", stage)
		}
		if result.lane != 2 || result.cursor != 4 || result.groupFilter != 1 || result.reviewScroll != 7 {
			t.Fatalf("verbose toggle changed navigation during %s", stage)
		}
		updated, _ = result.Update(tea.KeyPressMsg(tea.Key{Text: "v", Code: 'v'}))
		if updated.(model).verbose {
			t.Fatalf("second v did not restore compact mode during %s", stage)
		}
	}
}

func TestChooseEnterOpensReviewBeforeAcceptingSelection(t *testing.T) {
	m := model{apps: []application{{id: "app", label: "App", group: "tools", outcome: ensure}}, stage: "select", chooseOnly: true}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Code: tea.KeyEnter}))
	result := updated.(model)
	if result.stage != "review" || result.confirmed {
		t.Fatalf("Enter from planning should open review, got stage=%q confirmed=%t", result.stage, result.confirmed)
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
