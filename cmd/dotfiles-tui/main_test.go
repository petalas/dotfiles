package main

import (
	"fmt"
	"os"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
)

func TestRemovalConfirmationDisclosesAutomaticCleanupFallback(t *testing.T) {
	m := model{apps: []application{
		{id: "exact", label: "Exact", exact: "enabled", outcome: remove},
		{id: "fallback", label: "Fallback", exact: "disabled", cleanup: "enabled", outcome: remove},
	}}
	m.beginConfirmation()
	want := []string{"Fallback", "REMOVE 2"}
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

func TestPreparedCleanupFallbackUsesUnifiedRemovalReview(t *testing.T) {
	path := t.TempDir() + "/prepared.tsv"
	content := "format\t2\n" +
		"os\tmacos\n" +
		"app\tloose\tremove\toptional\ttools\tLoose\tpresent\tunverified\n" +
		"removal\tloose\tforce\tpath\t~/.local/bin/loose\t\n"
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	apps, steps, details, err := parsePrepared(path)
	if err != nil {
		t.Fatal(err)
	}
	m := model{apps: apps, steps: steps, reviewDetails: details, display: plain, stage: "review", confirmOnly: true, width: 80, height: 24}
	view := m.render()
	if apps[0].outcome != remove || !apps[0].cleanupFallback || !strings.Contains(view, "cleanup fallback") || strings.Contains(view, "Force") {
		t.Fatalf("prepared cleanup fallback was not presented as unified removal:\n%s", view)
	}
	m.beginConfirmation()
	if phrase := m.expectedPhrase(); phrase != "Loose" {
		t.Fatalf("cleanup fallback did not retain differentiated confirmation: %q", phrase)
	}
}

func TestPlanningViewFitsTerminalAndKeepsSelectionVisible(t *testing.T) {
	apps := make([]application, 20)
	for i := range apps {
		apps[i] = application{
			id: fmt.Sprintf("app-%02d", i+1), label: fmt.Sprintf("Application %02d", i+1),
			group: "tools", presence: "present", custody: "managed", policy: "optional",
			exact: "enabled", cleanup: "disabled", evidence: "registered by package manager", outcome: ensure,
		}
	}
	m := model{apps: apps, dependencies: map[string][]string{}, display: plain, stage: "select", chooseOnly: true, cursor: 20}
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
		t.Fatal("selected application must remain visible in the scrollable planning list")
	}
	for _, required := range []string{"[PLAN]", "REVIEW", "RUN", "Ensure", "Leave", "Remove", "Application 20 · present", "enter review", "q quit"} {
		if !strings.Contains(view, required) {
			t.Fatalf("planning view is missing persistent context or control %q", required)
		}
	}
	if strings.Contains(view, "Force") || strings.Contains(view, "/f") {
		t.Fatalf("planning view still exposes a separate force-removal option:\n%s", view)
	}
}

func TestRemoveUsesCleanupFallbackWhenExactRemovalIsUnavailable(t *testing.T) {
	m := model{apps: []application{{
		id: "unverified", label: "Unverified app", group: "tools", availability: "available", presence: "present",
		policy: "optional", exact: "disabled", cleanup: "enabled", outcome: ensure,
	}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18}
	m.cursor = 1 // Application leaf beneath the group root.
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	result := updated.(model)
	if result.apps[0].outcome != remove || result.notice != "" {
		t.Fatalf("r did not schedule automatic cleanup fallback: outcome=%q notice=%q", result.apps[0].outcome, result.notice)
	}
	result.stage = "review"
	if view := result.render(); !strings.Contains(view, "cleanup fallback") {
		t.Fatalf("review did not disclose cleanup fallback:\n%s", view)
	}
}

func TestRemoveCancelsPendingInstallForAbsentApplication(t *testing.T) {
	m := model{apps: []application{{
		id: "creative.gimp", label: "GIMP", group: "creative", availability: "available", presence: "absent",
		policy: "optional", exact: "disabled", cleanup: "disabled", outcome: ensure,
	}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18, cursor: 1}
	before := m.render()
	if !strings.Contains(before, "GIMP · absent -> present") {
		t.Fatalf("repro setup did not schedule the absent application for installation:\n%s", before)
	}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	result := updated.(model)
	after := result.render()
	if result.apps[0].outcome != remove || result.notice != "" || !strings.Contains(after, "GIMP · absent") || strings.Contains(after, "GIMP · absent -> present") {
		t.Fatalf("Remove did not cancel the pending install in place: outcome=%q notice=%q\n%s", result.apps[0].outcome, result.notice, after)
	}
}

func TestGroupRemoveCancelsPendingInstallsForAbsentApplications(t *testing.T) {
	m := model{apps: []application{
		{id: "creative.gimp", label: "GIMP", group: "creative", groupLabel: "Creative tools", availability: "available", presence: "absent", policy: "optional", exact: "disabled", cleanup: "disabled", outcome: ensure},
		{id: "creative.blender", label: "Blender", group: "creative", groupLabel: "Creative tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", cleanup: "enabled", outcome: ensure},
	}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 90, height: 18}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'})) // Selected group root.
	result := updated.(model)
	view := result.render()
	if result.apps[0].outcome != remove || result.apps[1].outcome != remove {
		t.Fatalf("group removal left an absent application pending installation: %#v", result.apps)
	}
	if !strings.Contains(view, "Remove 2") || !strings.Contains(view, "GIMP · absent") || strings.Contains(view, "GIMP · absent -> present") {
		t.Fatalf("group counts and absent row disagree after removal:\n%s", view)
	}
}

func TestCompleteAvailabilityPresenceOutcomeMatrix(t *testing.T) {
	tests := []struct {
		name, availability, presence string
		requested, result            outcome
		key                          rune
		accepted                     bool
		current, desired, row        string
		changed                      bool
	}{
		{name: "available/absent/ensure", availability: "available", presence: "absent", requested: ensure, result: ensure, key: 'e', accepted: true, current: "absent", desired: "present", row: "absent -> present", changed: true},
		{name: "available/absent/leave", availability: "available", presence: "absent", requested: leave, result: leave, key: 'u', accepted: true, current: "absent", desired: "absent", row: "absent"},
		{name: "available/absent/remove", availability: "available", presence: "absent", requested: remove, result: remove, key: 'r', accepted: true, current: "absent", desired: "removed", row: "absent"},
		{name: "available/partial/ensure", availability: "available", presence: "partial", requested: ensure, result: ensure, key: 'e', accepted: true, current: "partial", desired: "present", row: "partial -> present", changed: true},
		{name: "available/partial/leave", availability: "available", presence: "partial", requested: leave, result: leave, key: 'u', accepted: true, current: "partial", desired: "partial", row: "partial"},
		{name: "available/partial/remove", availability: "available", presence: "partial", requested: remove, result: remove, key: 'r', accepted: true, current: "partial", desired: "removed", row: "partial -> removed", changed: true},
		{name: "available/present/ensure", availability: "available", presence: "present", requested: ensure, result: ensure, key: 'e', accepted: true, current: "present", desired: "present", row: "present"},
		{name: "available/present/leave", availability: "available", presence: "present", requested: leave, result: leave, key: 'u', accepted: true, current: "present", desired: "present", row: "present"},
		{name: "available/present/remove", availability: "available", presence: "present", requested: remove, result: remove, key: 'r', accepted: true, current: "present", desired: "removed", row: "present -> removed", changed: true},
		{name: "available/unknown/ensure", availability: "available", presence: "unknown", requested: ensure, result: ensure, key: 'e', accepted: true, current: "unknown", desired: "present", row: "unknown -> present", changed: true},
		{name: "available/unknown/leave", availability: "available", presence: "unknown", requested: leave, result: leave, key: 'u', accepted: true, current: "unknown", desired: "unknown", row: "unknown"},
		{name: "available/unknown/remove", availability: "available", presence: "unknown", requested: remove, result: remove, key: 'r', accepted: true, current: "unknown", desired: "removed", row: "unknown -> removed", changed: true},
		{name: "unavailable/absent/ensure", availability: "unavailable", presence: "absent", requested: ensure, result: leave, key: 'e', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/absent/leave", availability: "unavailable", presence: "absent", requested: leave, result: leave, key: 'u', accepted: true, current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/absent/remove", availability: "unavailable", presence: "absent", requested: remove, result: leave, key: 'r', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/partial/ensure", availability: "unavailable", presence: "partial", requested: ensure, result: leave, key: 'e', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/partial/leave", availability: "unavailable", presence: "partial", requested: leave, result: leave, key: 'u', accepted: true, current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/partial/remove", availability: "unavailable", presence: "partial", requested: remove, result: leave, key: 'r', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/present/ensure", availability: "unavailable", presence: "present", requested: ensure, result: leave, key: 'e', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/present/leave", availability: "unavailable", presence: "present", requested: leave, result: leave, key: 'u', accepted: true, current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/present/remove", availability: "unavailable", presence: "present", requested: remove, result: leave, key: 'r', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/unknown/ensure", availability: "unavailable", presence: "unknown", requested: ensure, result: leave, key: 'e', current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/unknown/leave", availability: "unavailable", presence: "unknown", requested: leave, result: leave, key: 'u', accepted: true, current: "unavailable", desired: "unavailable", row: "unavailable"},
		{name: "unavailable/unknown/remove", availability: "unavailable", presence: "unknown", requested: remove, result: leave, key: 'r', current: "unavailable", desired: "unavailable", row: "unavailable"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			app := application{
				id: "app", label: "App", group: "tools", availability: test.availability, presence: test.presence,
				policy: "optional", exact: "enabled", cleanup: "enabled", outcome: leave,
			}
			m := model{apps: []application{app}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18, cursor: 1}
			updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: string(test.key), Code: test.key}))
			result := updated.(model)
			if result.apps[0].outcome != test.result {
				t.Fatalf("outcome: expected %q, got %q (notice %q)", test.result, result.apps[0].outcome, result.notice)
			}
			if test.accepted != (result.notice == "") {
				t.Fatalf("acceptance and notice disagree: accepted=%v notice=%q", test.accepted, result.notice)
			}
			current, desired, changed := stateTransitionValues(result.apps[0])
			if current != test.current || desired != test.desired || changed != test.changed {
				t.Fatalf("transition: expected %q -> %q changed=%v, got %q -> %q changed=%v", test.current, test.desired, test.changed, current, desired, changed)
			}
			view := result.render()
			if !strings.Contains(view, "App · "+test.row) {
				t.Fatalf("row does not show expected state %q:\n%s", test.row, view)
			}
			if !strings.Contains(view, fmt.Sprintf("%s 1", map[outcome]string{ensure: "Ensure", leave: "Leave", remove: "Remove"}[test.result])) {
				t.Fatalf("summary does not count outcome %q:\n%s", test.result, view)
			}
		})
	}
}

func TestCompleteRemovalCapabilityPresenceMatrix(t *testing.T) {
	presences := []string{"absent", "partial", "present", "unknown"}
	capabilities := []struct {
		name, exact, cleanup string
	}{
		{name: "neither", exact: "disabled", cleanup: "disabled"},
		{name: "exact", exact: "enabled", cleanup: "disabled"},
		{name: "cleanup", exact: "disabled", cleanup: "enabled"},
		{name: "both", exact: "enabled", cleanup: "enabled"},
	}
	for _, presence := range presences {
		for _, capability := range capabilities {
			t.Run(presence+"/"+capability.name, func(t *testing.T) {
				m := model{apps: []application{{
					id: "app", label: "App", group: "tools", availability: "available", presence: presence,
					policy: "optional", exact: capability.exact, cleanup: capability.cleanup, outcome: ensure,
				}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18, cursor: 1}
				updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
				result := updated.(model)
				accepted := presence == "absent" || capability.exact == "enabled" || capability.cleanup == "enabled"
				if accepted != (result.apps[0].outcome == remove) || accepted != (result.notice == "") {
					t.Fatalf("removal acceptance mismatch: accepted=%v outcome=%q notice=%q", accepted, result.apps[0].outcome, result.notice)
				}
				expectedFallback := accepted && presence != "absent" && capability.exact != "enabled" && capability.cleanup == "enabled"
				if result.apps[0].usesCleanupFallback() != expectedFallback {
					t.Fatalf("cleanup fallback: expected %v, got %v", expectedFallback, result.apps[0].usesCleanupFallback())
				}
			})
		}
	}
}

func TestRequiredPolicyOutcomeMatrix(t *testing.T) {
	requests := []struct {
		wanted outcome
		key    rune
	}{
		{wanted: ensure, key: 'e'},
		{wanted: leave, key: 'u'},
		{wanted: remove, key: 'r'},
	}
	for _, request := range requests {
		t.Run(string(request.wanted), func(t *testing.T) {
			m := model{apps: []application{{
				id: "required", label: "Required", group: "foundation", availability: "available", presence: "present",
				policy: "required", exact: "enabled", cleanup: "enabled", outcome: ensure,
			}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18, cursor: 1}
			updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: string(request.key), Code: request.key}))
			result := updated.(model)
			accepted := request.wanted == ensure
			if accepted != (result.notice == "") || result.apps[0].outcome != ensure {
				t.Fatalf("required policy mismatch: requested=%q outcome=%q notice=%q", request.wanted, result.apps[0].outcome, result.notice)
			}
		})
	}
}

func TestRetainedDependentRemovalPresenceMatrix(t *testing.T) {
	for _, presence := range []string{"absent", "partial", "present", "unknown"} {
		t.Run(presence, func(t *testing.T) {
			m := model{
				apps: []application{
					{id: "runtime", label: "Runtime", group: "tools", availability: "available", presence: presence, policy: "optional", exact: "enabled", cleanup: "enabled", outcome: ensure},
					{id: "client", label: "Client", group: "tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", cleanup: "enabled", outcome: leave},
				},
				dependencies: map[string][]string{"client": {"runtime"}}, display: plain, stage: "select", width: 80, height: 18, cursor: 1,
			}
			updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
			result := updated.(model)
			if result.apps[0].outcome != ensure || !strings.Contains(result.notice, "retained by Client") {
				t.Fatalf("retained dependent did not block %s prerequisite removal: outcome=%q notice=%q", presence, result.apps[0].outcome, result.notice)
			}
		})
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
			m := model{apps: []application{test.app}, display: plain, stage: "select", dependencies: map[string][]string{}, width: 80, height: 20}
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

func lineNumberContaining(content, value string) int {
	for index, line := range strings.Split(content, "\n") {
		if strings.Contains(line, value) {
			return index
		}
	}
	return -1
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
	for _, required := range []string{"[PLAN]", "REVIEW", "RUN", "Ensure", "Leave", "Remove", "Resize"} {
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
	for _, required := range []string{"PLAN", "[REVIEW]", "RUN", "Ensure", "Leave", "Remove", "Application 18", "enter accept", "choices esc back"} {
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
	}, dependencies: map[string][]string{}, groupFilter: 1, cursor: 1, display: plain, stage: "select", width: 80, height: 20}
	before := m.render()
	m.setGroupOutcome(remove)
	if m.apps[0].outcome != remove || m.apps[1].outcome != remove || m.apps[2].outcome != ensure {
		t.Fatalf("group action changed the wrong outcomes: %#v", m.apps)
	}
	if !strings.Contains(m.notice, "2 set to Remove") {
		t.Fatalf("group action did not report its result: %q", m.notice)
	}
	if m.cursor != 1 {
		t.Fatalf("group action moved the cursor to %d", m.cursor)
	}
	after := m.render()
	for _, label := range []string{"Game one", "Game two"} {
		if !strings.Contains(before, label) || !strings.Contains(after, label) {
			t.Fatalf("group action changed the visible list around %s", label)
		}
	}
	m.groupFilter = 0
	m.cursor = 1 // A child still targets its parent subtree without a group filter.
	m.setGroupOutcome(leave)
	if !strings.Contains(m.notice, "Gaming:") {
		t.Fatalf("child group action did not target its parent subtree, got %q", m.notice)
	}
}

func TestRemoveRejectsApplicationWithoutAnyCataloguedMethod(t *testing.T) {
	m := model{apps: []application{{
		id: "unsupported", label: "Unsupported app", group: "tools", availability: "available", presence: "present",
		policy: "optional", exact: "disabled", cleanup: "disabled", outcome: ensure,
	}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18, cursor: 1}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	result := updated.(model)
	if result.apps[0].outcome != ensure || result.notice != "Unsupported app has no supported removal method" {
		t.Fatalf("unsupported removal did not fail contextually: outcome=%q notice=%q", result.apps[0].outcome, result.notice)
	}
}

func TestDisabledReasonAppearsOnlyAfterRejectedAction(t *testing.T) {
	m := model{apps: []application{{id: "required", label: "Required app", group: "foundation", availability: "available", presence: "present", policy: "required", outcome: ensure}}, dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 18}
	before := m.render()
	if strings.Contains(before, "removal disabled") || strings.Contains(before, "is required") {
		t.Fatalf("disabled reason shifted the untouched planning tree:\n%s", before)
	}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	view := updated.(model).render()
	if !strings.Contains(view, "Required app is required") {
		t.Fatalf("rejected removal did not show a contextual hint:\n%s", view)
	}
	if lineNumberContaining(before, "◆ Required app") != lineNumberContaining(view, "◆ Required app") {
		t.Fatalf("contextual hint shifted the application tree:\nbefore:\n%s\nafter:\n%s", before, view)
	}
}

func TestGroupTreeTogglesSubtreeAndCollapsesInPlace(t *testing.T) {
	m := model{
		apps: []application{
			{id: "a", label: "Alpha", group: "cli", groupLabel: "CLI utilities", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
			{id: "b", label: "Bravo", group: "cli", groupLabel: "CLI utilities", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
			{id: "c", label: "Charlie", group: "development", groupLabel: "Development tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
		},
		dependencies: map[string][]string{}, display: plain, stage: "select", width: 90, height: 20,
	}
	view := m.render()
	for _, expected := range []string{"▼ CLI utilities", "├─", "Alpha", "Bravo", "▼ Development tools", "Charlie"} {
		if !strings.Contains(view, expected) {
			t.Fatalf("planning tree is missing %q:\n%s", expected, view)
		}
	}
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	result := updated.(model)
	if result.apps[0].outcome != remove || result.apps[1].outcome != remove || result.apps[2].outcome != ensure {
		t.Fatalf("group-row action did not toggle only its subtree: %#v", result.apps)
	}
	if result.cursor != 0 || !strings.Contains(result.render(), "Alpha") || !strings.Contains(result.render(), "Bravo") {
		t.Fatal("group-row action changed the visible tree or cursor")
	}
	collapsed, _ := result.Update(tea.KeyPressMsg(tea.Key{Code: tea.KeyLeft}))
	collapsedModel := collapsed.(model)
	if view := collapsedModel.render(); strings.Contains(view, "Alpha") || strings.Contains(view, "Bravo") || !strings.Contains(view, "CLI utilities") {
		t.Fatalf("left did not collapse the selected subtree:\n%s", view)
	}
	expanded, _ := collapsedModel.Update(tea.KeyPressMsg(tea.Key{Code: tea.KeyRight}))
	expandedModel := expanded.(model)
	if view := expandedModel.render(); !strings.Contains(view, "Alpha") || !strings.Contains(view, "Bravo") {
		t.Fatalf("right did not expand the selected subtree:\n%s", view)
	}
	expandedModel.cursor = 1 // Alpha leaf.
	parentChanged, _ := expandedModel.Update(tea.KeyPressMsg(tea.Key{Text: "U", Code: 'U'}))
	parentModel := parentChanged.(model)
	if parentModel.apps[0].outcome != leave || parentModel.apps[1].outcome != leave || parentModel.apps[2].outcome != ensure {
		t.Fatalf("uppercase leaf action did not target only its parent subtree: %#v", parentModel.apps)
	}
}

func TestItemOutcomeChangeKeepsPlanningListAndCursorStable(t *testing.T) {
	m := model{
		apps: []application{
			{id: "a", label: "Alpha", group: "tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
			{id: "b", label: "Bravo", group: "tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
			{id: "c", label: "Charlie", group: "tools", availability: "available", presence: "present", policy: "optional", exact: "enabled", outcome: ensure},
		},
		dependencies: map[string][]string{}, display: plain, stage: "select", width: 80, height: 20, cursor: 2,
	}
	before := m.render()
	updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "r", Code: 'r'}))
	result := updated.(model)
	if result.cursor != m.cursor || result.groupFilter != m.groupFilter {
		t.Fatalf("outcome change moved planning context: cursor=%d group=%d", result.cursor, result.groupFilter)
	}
	after := result.render()
	for _, label := range []string{"Alpha", "Bravo", "Charlie"} {
		if !strings.Contains(before, label) || !strings.Contains(after, label) {
			t.Fatalf("visible list changed around %s after outcome toggle:\n%s", label, after)
		}
	}
	if !strings.Contains(after, "Bravo · present -> removed") {
		t.Fatalf("selected row did not render its scheduled state immediately:\n%s", after)
	}
}

func TestVerboseKeyTogglesDetailWithoutLosingNavigation(t *testing.T) {
	for _, stage := range []string{"select", "review"} {
		m := model{apps: []application{{id: "app", label: "App", outcome: ensure}}, stage: stage, cursor: 4, groupFilter: 1, reviewScroll: 7}
		updated, _ := m.Update(tea.KeyPressMsg(tea.Key{Text: "v", Code: 'v'}))
		result := updated.(model)
		if !result.verbose {
			t.Fatalf("v did not enable verbose mode during %s", stage)
		}
		if result.cursor != 4 || result.groupFilter != 1 || result.reviewScroll != 7 {
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
		cursor:       1,
	}
	m.setSelectedOutcome(remove)
	if m.apps[0].outcome != ensure {
		t.Fatalf("retained dependent must keep prerequisite ensured, got %s", m.apps[0].outcome)
	}
	if m.notice == "" {
		t.Fatal("expected a visible disabled-removal reason")
	}
}
