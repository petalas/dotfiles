// dotfiles-tui is the visual, state-aware frontend for the installation engine.
package main

import (
	"bufio"
	"crypto/sha256"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"charm.land/bubbles/v2/progress"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

type outcome string

const (
	ensure      outcome = "ensure"
	leave       outcome = "leave"
	remove      outcome = "remove"
	legacyForce outcome = "force"
)

var orderedOutcomes = []outcome{ensure, leave, remove}
var outcomeTitles = map[outcome]string{ensure: "ENSURE PRESENT", leave: "LEAVE UNCHANGED", remove: "REMOVE"}

type planStep struct {
	id, label string
	enabled   bool
}

type application struct {
	id, group, groupLabel, label, availability, presence, custody, policy, exact, cleanup, evidence string
	outcome                                                                                         outcome
	cleanupFallback                                                                                 bool
}

func (app application) usesCleanupFallback() bool {
	return app.outcome == remove && app.presence != "absent" && (app.cleanupFallback || app.exact != "enabled" && app.cleanup == "enabled")
}

type displayMode string

const (
	rich  displayMode = "rich"
	ascii displayMode = "ascii"
	plain displayMode = "plain"
)

type model struct {
	apps                 []application
	steps                []planStep
	dependencies         map[string][]string
	reviewDetails        []string
	width, height        int
	cursor               int
	groupFilter          int
	reviewScroll         int
	display              displayMode
	stage, input, notice string
	stepMode             bool
	stepCursor           int
	arm                  int
	output               string
	confirmed, cancelled bool
	chooseOnly           bool
	confirmOnly          bool
	interactive          bool
	verbose              bool
	collapsedGroups      map[string]bool
}

func parseInputs(observationsPath, selectionPath string) ([]application, []planStep, map[string][]string, error) {
	selected := map[string]outcome{}
	groupLabels := map[string]string{}
	steps := []planStep{}
	dependencies := map[string][]string{}
	if err := scanTSV(selectionPath, func(fields []string) error {
		switch {
		case len(fields) == 3 && fields[0] == "outcome":
			switch outcome(fields[2]) {
			case ensure, leave, remove:
				selected[fields[1]] = outcome(fields[2])
			case legacyForce:
				selected[fields[1]] = remove
			default:
				return fmt.Errorf("invalid desired outcome for %s", fields[1])
			}
		case len(fields) == 3 && fields[0] == "group":
			if fields[1] == "" || fields[2] == "" || groupLabels[fields[1]] != "" {
				return fmt.Errorf("invalid or duplicate group %q", fields[1])
			}
			groupLabels[fields[1]] = fields[2]
		case len(fields) == 4 && fields[0] == "step":
			if fields[2] != "on" && fields[2] != "off" {
				return fmt.Errorf("invalid step state for %s", fields[1])
			}
			steps = append(steps, planStep{id: fields[1], label: fields[3], enabled: fields[2] == "on"})
		case len(fields) == 3 && fields[0] == "dependency":
			dependencies[fields[1]] = append(dependencies[fields[1]], fields[2])
		default:
			return fmt.Errorf("unknown selection record %q", fields[0])
		}
		return nil
	}); err != nil {
		return nil, nil, nil, err
	}
	apps := []application{}
	err := scanTSV(observationsPath, func(fields []string) error {
		if len(fields) == 11 && fields[0] == "observation" {
			wanted, ok := selected[fields[1]]
			if !ok {
				wanted = leave
			}
			apps = append(apps, application{
				id: fields[1], availability: fields[2], presence: fields[3], custody: fields[4], policy: fields[5],
				exact: fields[6], cleanup: fields[7], group: fields[8], groupLabel: groupLabels[fields[8]], label: fields[9],
				evidence: fields[10], outcome: wanted,
			})
			return nil
		}
		if len(fields) == 2 && fields[0] == "os" {
			return nil
		}
		if len(fields) == 5 && fields[0] == "mechanism" {
			return nil
		}
		return fmt.Errorf("unknown observation record %q", fields[0])
	})
	if err != nil {
		return nil, nil, nil, err
	}
	if len(apps) == 0 {
		return nil, nil, nil, errors.New("observation artifact contains no applications")
	}
	return apps, steps, dependencies, nil
}

func scanTSV(path string, visit func([]string) error) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	formatSeen := false
	for scanner.Scan() {
		fields := strings.Split(scanner.Text(), "\t")
		if len(fields) == 2 && fields[0] == "format" {
			if fields[1] != "1" || formatSeen {
				return fmt.Errorf("unsupported or duplicate format in %s", path)
			}
			formatSeen = true
			continue
		}
		if err := visit(fields); err != nil {
			return err
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if !formatSeen {
		return fmt.Errorf("format is missing from %s", path)
	}
	return nil
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyPressMsg:
		key := msg.String()
		if key == "ctrl+c" || key == "q" && (m.stage == "select" || (m.confirmOnly && m.stage == "review")) {
			m.cancelled = true
			return m, tea.Quit
		}
		if key == "v" && (m.stage == "select" || m.stage == "review") {
			m.verbose = !m.verbose
			return m, nil
		}
		if m.stage == "confirm" {
			return m.updateConfirmation(key)
		}
		if m.stage == "review" {
			return m.updateReview(key)
		}
		if key == "tab" && len(m.steps) > 0 {
			m.stepMode = !m.stepMode
			return m, nil
		}
		if m.stepMode {
			switch key {
			case "up", "k":
				if m.stepCursor > 0 {
					m.stepCursor--
				}
			case "down", "j":
				if m.stepCursor+1 < len(m.steps) {
					m.stepCursor++
				}
			case "space":
				m.steps[m.stepCursor].enabled = !m.steps[m.stepCursor].enabled
			case "enter":
				m.stage = "review"
			}
			return m, nil
		}
		switch key {
		case "left", "h":
			m.collapseSelectedGroup()
		case "right", "l":
			m.expandSelectedGroup()
		case "space":
			m.toggleSelectedGroup()
		case "[":
			if m.groupFilter > 0 {
				m.groupFilter--
				m.cursor = 0
			}
		case "]":
			if m.groupFilter+1 < len(m.groupFilters()) {
				m.groupFilter++
				m.cursor = 0
			}
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor+1 < len(m.planningNodes()) {
				m.cursor++
			}
		case "pgup":
			m.cursor = max(0, m.cursor-5)
		case "pgdown":
			m.cursor = min(max(0, len(m.planningNodes())-1), m.cursor+5)
		case "e":
			m.setSelectedOutcome(ensure)
		case "u":
			m.setSelectedOutcome(leave)
		case "r":
			m.setSelectedOutcome(remove)
		case "E":
			m.setGroupOutcome(ensure)
		case "U":
			m.setGroupOutcome(leave)
		case "R":
			m.setGroupOutcome(remove)
		case "enter":
			m.stage, m.reviewScroll = "review", 0
		}
	}
	return m, nil
}

func (m model) updateReview(key string) (tea.Model, tea.Cmd) {
	page := max(3, m.contentHeight()-4)
	switch key {
	case "up", "k":
		m.reviewScroll = max(0, m.reviewScroll-1)
	case "down", "j":
		m.reviewScroll++
	case "pgup":
		m.reviewScroll = max(0, m.reviewScroll-page)
	case "pgdown":
		m.reviewScroll += page
	case "home":
		m.reviewScroll = 0
	case "end":
		m.reviewScroll = 1 << 20
	case "esc":
		if m.confirmOnly {
			m.cancelled = true
			return m, tea.Quit
		}
		m.stage, m.reviewScroll = "select", 0
	case "enter":
		if m.chooseOnly {
			m.confirmed = true
			return m, tea.Quit
		}
		m.beginConfirmation()
	}
	return m, nil
}

func (m model) updateConfirmation(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "esc":
		m.stage, m.input, m.arm = "review", "", 0
	case "backspace":
		if len(m.input) > 0 {
			m.input = m.input[:len(m.input)-1]
		}
	case "enter":
		if m.input != m.expectedPhrase() {
			return m, nil
		}
		m.input = ""
		m.arm++
		if m.arm < m.confirmationStepCount() {
			return m, nil
		}
		m.confirmed = true
		return m, tea.Quit
	default:
		if len([]rune(key)) == 1 || key == "space" {
			if key == "space" {
				key = " "
			}
			m.input += key
		}
	}
	return m, nil
}

func (m *model) beginConfirmation() {
	m.stage, m.input, m.arm = "confirm", "", 0
}

func (m model) confirmationStepCount() int {
	count := len(m.appsUsingCleanupFallback())
	if len(m.appsWithOutcome(remove)) > 0 {
		count++
	}
	if count == 0 {
		return 1
	}
	return count
}

func (m model) expectedPhrase() string {
	fallbacks := m.appsUsingCleanupFallback()
	if m.arm < len(fallbacks) {
		return fallbacks[m.arm].label
	}
	if removals := len(m.appsWithOutcome(remove)); removals > 0 && m.arm == len(fallbacks) {
		return fmt.Sprintf("REMOVE %d", removals)
	}
	return "START"
}

func (m model) appsUsingCleanupFallback() []application {
	apps := []application{}
	for _, app := range m.apps {
		if app.usesCleanupFallback() {
			apps = append(apps, app)
		}
	}
	return apps
}

func (m *model) setSelectedOutcome(next outcome) {
	nodes := m.planningNodes()
	if m.cursor >= len(nodes) {
		return
	}
	node := nodes[m.cursor]
	if node.isGroup() {
		m.setGroupOutcomeFor(node.group, next)
		return
	}
	if reason := m.trySetOutcome(node.appIndex, next); reason != "" {
		m.notice = reason
		return
	}
	m.notice = ""
}

func (m *model) trySetOutcome(index int, next outcome) string {
	app := m.apps[index]
	if app.availability == "unavailable" && next != leave {
		return app.label + " is unavailable on this platform"
	}
	if app.policy == "required" && next != ensure {
		return app.label + " is required"
	}
	if next == remove && m.retainedDependent(app.id) != "" {
		return app.label + " is retained by " + m.retainedDependent(app.id)
	}
	if next == remove && app.presence != "absent" && app.exact != "enabled" && app.cleanup != "enabled" {
		return app.label + " has no supported removal method"
	}
	m.apps[index].outcome = next
	if next == ensure {
		for _, prerequisite := range m.dependencies[app.id] {
			m.setOutcomeByID(prerequisite, ensure)
		}
	} else if next == leave {
		for _, prerequisite := range m.dependencies[app.id] {
			if current := m.appByID(prerequisite); current != nil && current.outcome == remove {
				m.setOutcomeByID(prerequisite, leave)
			}
		}
	}
	return ""
}

func (m *model) setGroupOutcome(next outcome) {
	nodes := m.planningNodes()
	if m.cursor >= len(nodes) {
		return
	}
	m.setGroupOutcomeFor(nodes[m.cursor].group, next)
}

func (m *model) setGroupOutcomeFor(group string, next outcome) {
	indices := []int{}
	for i := range m.apps {
		if m.apps[i].group == group {
			indices = append(indices, i)
		}
	}
	if next == remove {
		for left, right := 0, len(indices)-1; left < right; left, right = left+1, right-1 {
			indices[left], indices[right] = indices[right], indices[left]
		}
	}
	changed, skipped, firstReason := 0, 0, ""
	for _, index := range indices {
		if reason := m.trySetOutcome(index, next); reason != "" {
			skipped++
			if firstReason == "" {
				firstReason = reason
			}
		} else {
			changed++
		}
	}
	m.notice = fmt.Sprintf("%s: %d set to %s", m.groupLabel(group), changed, outcomeLabel(next))
	if skipped > 0 {
		m.notice += fmt.Sprintf("; %d unchanged (%s)", skipped, firstReason)
	}
}

func (m *model) setOutcomeByID(id string, wanted outcome) {
	for i := range m.apps {
		if m.apps[i].id == id {
			m.apps[i].outcome = wanted
			return
		}
	}
}
func (m model) appByID(id string) *application {
	for i := range m.apps {
		if m.apps[i].id == id {
			app := m.apps[i]
			return &app
		}
	}
	return nil
}
func (m model) retainedDependent(prerequisite string) string {
	for dependent, prerequisites := range m.dependencies {
		for _, candidate := range prerequisites {
			if candidate != prerequisite {
				continue
			}
			app := m.appByID(dependent)
			if app == nil {
				continue
			}
			if app.outcome != remove && app.presence != "absent" {
				return app.label
			}
		}
	}
	return ""
}

func (m model) groupFilters() []string {
	groups := []string{"All groups"}
	seen := map[string]bool{}
	for _, app := range m.apps {
		if !seen[app.group] {
			seen[app.group] = true
			groups = append(groups, app.group)
		}
	}
	return groups
}
func (m model) appsWithOutcomeInGroup(wanted outcome) []application {
	apps := filterApps(m.apps, wanted)
	if m.groupFilter == 0 {
		return apps
	}
	group := m.groupFilters()[m.groupFilter]
	filtered := []application{}
	for _, app := range apps {
		if app.group == group {
			filtered = append(filtered, app)
		}
	}
	return filtered
}

type planningNode struct {
	group     string
	label     string
	appIndex  int
	lastChild bool
}

func (node planningNode) isGroup() bool { return node.appIndex < 0 }

func (m model) groupLabel(group string) string {
	if group == "" {
		return "Applications"
	}
	for _, app := range m.apps {
		if app.group == group && app.groupLabel != "" {
			return app.groupLabel
		}
	}
	special := map[string]string{"ai": "AI", "cad": "CAD", "cli": "CLI utilities"}
	if label := special[group]; label != "" {
		return label
	}
	return strings.ToUpper(group[:1]) + strings.ReplaceAll(group[1:], "-", " ")
}

func (m model) planningNodes() []planningNode {
	groups := []string{}
	seen := map[string]bool{}
	selectedGroup := ""
	if m.groupFilter > 0 {
		selectedGroup = m.groupFilters()[m.groupFilter]
	}
	for _, app := range m.apps {
		if selectedGroup != "" && app.group != selectedGroup || seen[app.group] {
			continue
		}
		seen[app.group] = true
		groups = append(groups, app.group)
	}
	nodes := []planningNode{}
	for _, group := range groups {
		nodes = append(nodes, planningNode{group: group, label: m.groupLabel(group), appIndex: -1})
		if m.collapsedGroups[group] {
			continue
		}
		indices := []int{}
		for index := range m.apps {
			if m.apps[index].group == group {
				indices = append(indices, index)
			}
		}
		for position, index := range indices {
			nodes = append(nodes, planningNode{group: group, appIndex: index, lastChild: position == len(indices)-1})
		}
	}
	return nodes
}

func (m *model) ensureCollapsedGroups() {
	if m.collapsedGroups == nil {
		m.collapsedGroups = map[string]bool{}
	}
}

func (m *model) collapseSelectedGroup() {
	nodes := m.planningNodes()
	if m.cursor >= len(nodes) {
		return
	}
	node := nodes[m.cursor]
	if !node.isGroup() {
		for m.cursor > 0 && !nodes[m.cursor].isGroup() {
			m.cursor--
		}
		return
	}
	m.ensureCollapsedGroups()
	m.collapsedGroups[node.group] = true
}

func (m *model) expandSelectedGroup() {
	nodes := m.planningNodes()
	if m.cursor >= len(nodes) || !nodes[m.cursor].isGroup() {
		return
	}
	m.ensureCollapsedGroups()
	delete(m.collapsedGroups, nodes[m.cursor].group)
}

func (m *model) toggleSelectedGroup() {
	nodes := m.planningNodes()
	if m.cursor >= len(nodes) || !nodes[m.cursor].isGroup() {
		return
	}
	if m.collapsedGroups[nodes[m.cursor].group] {
		m.expandSelectedGroup()
	} else {
		m.collapseSelectedGroup()
	}
}
func (m model) appsWithOutcome(wanted outcome) []application { return filterApps(m.apps, wanted) }
func filterApps(apps []application, wanted outcome) []application {
	filtered := []application{}
	for _, app := range apps {
		if app.outcome == wanted {
			filtered = append(filtered, app)
		}
	}
	return filtered
}

func (m model) View() tea.View {
	view := tea.NewView(m.render())
	view.AltScreen = m.interactive
	return view
}

func (m model) render() string {
	if m.stage == "review" || m.stage == "confirm" {
		return m.renderReview()
	}
	return m.renderPlan()
}

func (m model) screenWidth() int {
	if m.width > 0 {
		return max(1, m.width)
	}
	return 120
}

func (m model) contentHeight() int {
	if m.height > 0 {
		return max(1, m.height)
	}
	return 30
}

func (m model) separator() string {
	if m.display == ascii {
		return " | "
	}
	return " · "
}

func (m model) renderPlan() string {
	width, height := m.screenWidth(), m.contentHeight()
	if width < 40 || height < 14 {
		return compactContext("plan", m.separator(), "Resize to at least 40x14", "q quit", width, height)
	}
	group := m.groupFilters()[m.groupFilter]
	groupDisplay := group
	if m.groupFilter > 0 {
		groupDisplay = m.groupLabel(group)
	}
	managed, changes, warnings := 0, 0, 0
	for _, app := range m.apps {
		if app.presence == "present" && app.custody == "managed" {
			managed++
		}
		if app.outcome == ensure && app.presence != "present" ||
			app.outcome == remove && app.presence != "absent" {
			changes++
		}
		if app.presence == "present" && app.custody == "unverified" {
			warnings++
		}
	}
	sep := m.separator()
	header := []string{fit(stageStepper("plan", sep), width)}
	header = append(header, fit("DOTFILES"+sep+fmt.Sprintf("%d applications", len(m.apps))+sep+"group: "+groupDisplay, width))
	status := fmt.Sprintf("managed %d%splanned changes %d%scustody warnings %d", managed, sep, changes, sep, warnings)
	if m.notice != "" {
		status = "! " + m.notice
	}
	header = append(header, fit(status, width))
	header = append(header, wrapSegments(m.outcomeSummaryParts(), sep, width)...)
	if len(m.steps) > 0 {
		line := "Steps:"
		for i, step := range m.steps {
			mark := " "
			if step.enabled {
				mark = "x"
			}
			cursor := ""
			if m.stepMode && i == m.stepCursor {
				cursor = ">"
			}
			line += fmt.Sprintf("  %s[%s] %s", cursor, mark, step.label)
		}
		header = append(header, fit(line, width))
	}
	footer := wrapWords("up/down select  left/right collapse/expand  e/u/r set node outcome", width)
	footer = append(footer, wrapWords("Shift+E/U/R parent group  [/] filter group  tab steps", width)...)
	detailControl := "v show details"
	if m.verbose {
		detailControl = "v hide details"
	}
	footer = append(footer, wrapWords("pgup/pgdown page  "+detailControl+"  enter review  q quit", width)...)
	bodyHeight := max(1, height-len(header)-len(footer))
	body := strings.Split(m.renderPlanningTree(width, bodyHeight), "\n")
	lines := append(header, body...)
	lines = append(lines, footer...)
	return fitScreen(lines, width, height)
}

func compactContext(active, separator, message, control string, width, height int) string {
	stageParts := []string{"PLAN", "REVIEW", "RUN"}
	for i := range stageParts {
		if strings.EqualFold(stageParts[i], active) {
			stageParts[i] = "[" + stageParts[i] + "]"
		}
	}
	lines := []string{fit("STAGES", width)}
	lines = append(lines, wrapSegments(stageParts, separator, width)...)
	lines = append(lines, fit("OUTCOMES", width))
	lines = append(lines, wrapSegments([]string{"Ensure", "Leave", "Remove"}, separator, width)...)
	lines = append(lines, wrapWords(message, width)...)
	if control != "" {
		lines = append(lines, wrapWords(control, width)...)
	}
	return fitScreen(lines, width, height)
}

func stageStepper(active, separator string) string {
	stages := []string{"plan", "review", "run"}
	parts := make([]string, 0, len(stages))
	for _, stage := range stages {
		label := strings.ToUpper(stage)
		if stage == active {
			label = "[" + label + "]"
		}
		parts = append(parts, label)
	}
	return "STAGES  " + strings.Join(parts, separator)
}

func (m model) outcomeSummaryParts() []string {
	labels := map[outcome]string{ensure: "Ensure", leave: "Leave", remove: "Remove"}
	parts := make([]string, 0, len(orderedOutcomes))
	for _, wanted := range orderedOutcomes {
		parts = append(parts, fmt.Sprintf("%s %d", labels[wanted], len(m.appsWithOutcomeInGroup(wanted))))
	}
	return parts
}

func wrapSegments(parts []string, separator string, width int) []string {
	lines := []string{}
	current := ""
	for _, part := range parts {
		candidate := part
		if current != "" {
			candidate = current + separator + part
		}
		if current == "" || lipgloss.Width(candidate) <= width {
			current = candidate
			continue
		}
		lines = append(lines, fit(current, width))
		current = part
	}
	if current != "" {
		lines = append(lines, fit(current, width))
	}
	return lines
}

func outcomeLabel(wanted outcome) string {
	switch wanted {
	case ensure:
		return "Ensure present"
	case leave:
		return "Leave unchanged"
	case remove:
		return "Remove"
	default:
		return string(wanted)
	}
}

func (m model) renderPlanningTree(width, height int) string {
	nodes := m.planningNodes()
	if height <= 0 {
		return ""
	}
	appCount := len(m.apps)
	if m.groupFilter > 0 {
		appCount = 0
		group := m.groupFilters()[m.groupFilter]
		for _, app := range m.apps {
			if app.group == group {
				appCount++
			}
		}
	}
	title := fmt.Sprintf("APPLICATION TREE (%d apps)", appCount)
	if len(nodes) > 0 {
		title += fmt.Sprintf("  node %d/%d", min(m.cursor+1, len(nodes)), len(nodes))
	}
	if len(nodes) == 0 {
		return strings.Join([]string{fit(title, width), fit("  (empty)", width)}, "\n")
	}

	lines := []string{}
	selectedStart, selectedEnd := 0, 0
	for index, node := range nodes {
		start := len(lines)
		cursor := "  "
		if index == m.cursor {
			cursor = "> "
		}
		if node.isGroup() {
			marker := "▼"
			if m.collapsedGroups[node.group] {
				marker = "▶"
			}
			if m.display == ascii {
				if m.collapsedGroups[node.group] {
					marker = ">"
				} else {
					marker = "v"
				}
			}
			line := cursor + marker + " " + node.label + m.separator() + m.groupOutcomeSummary(node.group)
			if m.display == rich {
				line = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("6")).Render(line)
			}
			lines = append(lines, fit(line, width))
		} else {
			branch := "├─ "
			if node.lastChild {
				branch = "└─ "
			}
			if m.display == ascii {
				branch = "|- "
				if node.lastChild {
					branch = "\\- "
				}
			}
			app := m.apps[node.appIndex]
			item := m.renderApplicationLabel(cursor+"  "+branch, app)
			if m.verbose {
				lines = append(lines, fit(item, width))
				lines = append(lines, fit("        State: "+m.renderStateTransition(app), width))
				lines = append(lines, fit("        Custody: "+app.custody, width))
				lines = append(lines, fit("        Evidence: "+app.evidence, width))
				lines = append(lines, "")
			} else {
				lines = append(lines, fit(item+m.separator()+m.renderStateTransition(app), width))
			}
		}
		if index == m.cursor {
			selectedStart, selectedEnd = start, len(lines)-1
		}
	}
	up, down := "↑ more", "↓ more"
	if m.display == ascii {
		up, down = "^ more", "v more"
	}
	visible := viewportAround(lines, selectedStart, selectedEnd, max(0, height-1), width, up, down)
	return strings.Join(append([]string{fit(title, width)}, visible...), "\n")
}

func (m model) groupOutcomeSummary(group string) string {
	counts := map[outcome]int{}
	for _, app := range m.apps {
		if app.group == group {
			counts[app.outcome]++
		}
	}
	return fmt.Sprintf("Ensure %d%sLeave %d%sRemove %d", counts[ensure], m.separator(), counts[leave], m.separator(), counts[remove])
}

func stateTransitionValues(app application) (string, string, bool) {
	current := app.presence
	if app.availability == "unavailable" {
		current = "unavailable"
	}
	desired := current
	switch app.outcome {
	case ensure:
		desired = "present"
	case remove:
		desired = "removed"
	}
	changed := current != desired && !(current == "absent" && desired == "removed") && current != "unavailable"
	return current, desired, changed
}

func (m model) stateTransition(app application) string {
	current, desired, changed := stateTransitionValues(app)
	if !changed {
		return current
	}
	return current + " -> " + desired
}

func (m model) stateStyle(state string) lipgloss.Style {
	color := lipgloss.Color("1")
	switch state {
	case "present":
		color = lipgloss.Color("2")
	case "partial":
		color = lipgloss.Color("3")
	case "absent":
		color = lipgloss.Color("8")
	case "removed":
		color = lipgloss.Color("1")
	}
	return lipgloss.NewStyle().Foreground(color)
}

func (m model) colorState(value, state string) string {
	if m.display != rich {
		return value
	}
	return m.stateStyle(state).Render(value)
}

func (m model) renderApplicationLabel(cursor string, app application) string {
	label := cursor + m.marker(app) + " " + app.label
	current, _, _ := stateTransitionValues(app)
	return m.colorState(label, current)
}

func (m model) renderStateTransition(app application) string {
	current, desired, changed := stateTransitionValues(app)
	if !changed {
		return m.colorState(current, current)
	}
	return m.colorState(current, current) + " -> " + m.colorState(desired, desired)
}

func (m model) marker(app application) string {
	if app.policy == "required" {
		if m.display == ascii {
			return "[!]"
		}
		return "◆"
	}
	if m.display == ascii {
		switch app.presence {
		case "present":
			return "[+]"
		case "partial":
			return "[~]"
		case "absent":
			return "[-]"
		default:
			return "[?]"
		}
	}
	switch app.presence {
	case "present":
		return "●"
	case "partial":
		return "◐"
	case "absent":
		return "○"
	default:
		return "?"
	}
}

func (m model) renderReview() string {
	width, height := m.screenWidth(), m.contentHeight()
	if width < 40 || height < 14 {
		return compactContext("review", m.separator(), "Resize to at least 40x14", "esc back", width, height)
	}
	var b strings.Builder
	title := "REVIEW CHOICES"
	if m.confirmOnly {
		title = "REVIEW PREPARED RUN"
	}
	fmt.Fprintf(&b, "%s\n\nSTEPS\n", title)
	for _, step := range m.steps {
		state := "off"
		if step.enabled {
			state = "on"
		}
		fmt.Fprintf(&b, "  [%s] %s\n", state, step.label)
	}
	fmt.Fprintln(&b)
	for _, wanted := range orderedOutcomes {
		apps := m.appsWithOutcome(wanted)
		fmt.Fprintf(&b, "%s (%d)\n", outcomeTitles[wanted], len(apps))
		for _, app := range apps {
			label := m.renderApplicationLabel("  ", app)
			method := ""
			if wanted == remove && app.usesCleanupFallback() {
				method = m.separator() + "cleanup fallback"
			}
			if m.verbose {
				fmt.Fprintf(&b, "%s%s%s%s%s%s\n", label, m.separator(), m.renderStateTransition(app), method, m.separator(), app.evidence)
			} else {
				fmt.Fprintf(&b, "%s%s%s%s\n", label, m.separator(), m.renderStateTransition(app), method)
			}
		}
	}
	if len(m.reviewDetails) > 0 {
		fmt.Fprintln(&b, "\nMETHODS AND BLOCKERS")
		for _, detail := range m.reviewDetails {
			fmt.Fprintf(&b, "  %s\n", detail)
		}
	}
	body := wrapIndentedLines(strings.TrimSuffix(b.String(), "\n"), width)
	header := []string{fit(stageStepper("review", m.separator()), width)}
	header = append(header, wrapSegments(m.outcomeSummaryParts(), m.separator(), width)...)
	footer := []string{}
	if m.stage == "confirm" {
		footer = append(footer, fit(fmt.Sprintf("Type %q to continue:", m.expectedPhrase()), width))
		footer = append(footer, fit("> "+m.input, width))
		footer = append(footer, fit("backspace edits  enter confirms  esc returns to review", width))
	} else {
		verb := "continue to confirmation"
		if m.chooseOnly {
			verb = "accept choices"
		}
		detailControl := "v show details"
		if m.verbose {
			detailControl = "v hide details"
		}
		footer = append(footer, wrapWords("up/down scroll  pgup/pgdown page  "+detailControl+"  enter "+verb+"  esc back", width)...)
	}
	bodyHeight := max(1, height-len(header)-len(footer))
	up, down := "↑ earlier", "↓ more"
	if m.display == ascii {
		up, down = "^ earlier", "v more"
	}
	visible := viewportAt(body, m.reviewScroll, bodyHeight, width, up, down)
	lines := append(header, visible...)
	return fitScreen(append(lines, footer...), width, height)
}

func wrapIndentedLines(content string, width int) []string {
	result := []string{}
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimLeft(line, " ")
		indent := line[:len(line)-len(trimmed)]
		if trimmed == "" {
			result = append(result, "")
			continue
		}
		available := max(1, width-lipgloss.Width(indent))
		wrapped := wrapWords(trimmed, available)
		for _, part := range wrapped {
			result = append(result, fit(indent+strings.TrimRight(part, " "), width))
		}
	}
	return result
}

func viewportAt(lines []string, offset, height, width int, up, down string) []string {
	if height <= 0 || len(lines) == 0 {
		return nil
	}
	if len(lines) <= height {
		return lines
	}
	if height == 1 {
		return []string{lines[min(max(0, offset), len(lines)-1)]}
	}
	offset = max(0, offset)
	atBottom := offset >= len(lines)-height
	if atBottom {
		start := max(0, len(lines)-(height-1))
		return append([]string{fit(up, width)}, lines[start:]...)
	}
	visible := []string{}
	capacity := height - 1 // Keep the lower scroll affordance visible.
	if offset > 0 {
		visible = append(visible, fit(up, width))
		capacity--
	}
	end := min(len(lines), offset+capacity)
	visible = append(visible, lines[offset:end]...)
	visible = append(visible, fit(down, width))
	return visible
}

func joinColumns(columns []string, width int) string {
	split := make([][]string, len(columns))
	height := 0
	for i, column := range columns {
		split[i] = strings.Split(column, "\n")
		if len(split[i]) > height {
			height = len(split[i])
		}
	}
	var b strings.Builder
	for row := 0; row < height; row++ {
		for col := range split {
			line := ""
			if row < len(split[col]) {
				line = split[col][row]
			}
			b.WriteString(fit(line, width))
			if col+1 < len(split) {
				b.WriteByte(' ')
			}
		}
		b.WriteByte('\n')
	}
	return b.String()
}

func fit(value string, width int) string {
	if width <= 0 {
		return ""
	}
	if lipgloss.Width(value) <= width {
		return value + strings.Repeat(" ", width-lipgloss.Width(value))
	}
	if width == 1 {
		return ansi.Truncate(value, 1, "")
	}
	return ansi.Truncate(value, width, "…")
}

func wrapWords(value string, width int) []string {
	if width <= 0 {
		return nil
	}
	words := strings.Fields(value)
	if len(words) == 0 {
		return []string{""}
	}
	lines := []string{}
	current := ""
	for _, word := range words {
		candidate := word
		if current != "" {
			candidate = current + " " + word
		}
		if lipgloss.Width(candidate) <= width {
			current = candidate
			continue
		}
		if current != "" {
			lines = append(lines, fit(current, width))
		}
		current = word
	}
	if current != "" {
		lines = append(lines, fit(current, width))
	}
	return lines
}

func fitScreen(lines []string, width, height int) string {
	if height > 0 && len(lines) > height {
		lines = lines[:height]
	}
	for i := range lines {
		lines[i] = fit(strings.TrimRight(lines[i], " "), width)
	}
	return strings.TrimRight(strings.Join(lines, "\n"), " ") + "\n"
}

func viewportAround(lines []string, selectedStart, _ int, height, width int, up, down string) []string {
	if height <= 0 || len(lines) == 0 {
		return nil
	}
	if len(lines) <= height {
		return lines
	}
	if height == 1 {
		return []string{lines[min(selectedStart, len(lines)-1)]}
	}
	start := max(0, selectedStart-height/2)
	top := start > 0
	capacity := height
	if top {
		capacity--
	}
	end := min(len(lines), start+capacity)
	bottom := end < len(lines)
	if bottom && capacity > 1 {
		end--
	}
	if selectedStart >= end {
		end = min(len(lines), selectedStart+1)
		start = max(0, end-capacity)
		top = start > 0
	}
	visible := make([]string, 0, height)
	if top {
		visible = append(visible, fit("  "+up, width))
	}
	visible = append(visible, lines[start:end]...)
	if end < len(lines) && len(visible) < height {
		visible = append(visible, fit("  "+down, width))
	}
	if len(visible) > height {
		visible = visible[:height]
	}
	return visible
}

func parsePrepared(path string) ([]application, []planStep, []string, error) {
	apps := []application{}
	steps := []planStep{}
	details := []string{}
	err := scanPrepared(path, func(fields []string) error {
		if len(fields) == 8 && fields[0] == "app" {
			wanted := outcome(fields[2])
			cleanupFallback := wanted == legacyForce
			if cleanupFallback {
				wanted = remove
			}
			apps = append(apps, application{id: fields[1], outcome: wanted, policy: fields[3],
				group: fields[4], label: fields[5], presence: fields[6], custody: fields[7], evidence: fields[6] + " · " + fields[7], cleanupFallback: cleanupFallback})
			return nil
		}
		if len(fields) == 5 && fields[0] == "step" {
			steps = append(steps, planStep{id: fields[1], enabled: fields[2] == "on", label: fields[4]})
			return nil
		}
		if len(fields) == 6 && fields[0] == "removal" {
			mode := fields[2]
			if mode == "force" {
				mode = "cleanup fallback"
				for index := range apps {
					if apps[index].id == fields[1] {
						apps[index].cleanupFallback = true
					}
				}
			}
			details = append(details, fmt.Sprintf("%s: %s %s (%s)", mode, fields[3], fields[4], fields[1]))
			return nil
		}
		if len(fields) == 4 && fields[0] == "blocker" {
			details = append(details, fmt.Sprintf("blocked %s: %s %s", fields[1], fields[2], fields[3]))
			return nil
		}
		switch fields[0] {
		case "os", "dependency", "action", "step-action":
			return nil
		}
		return fmt.Errorf("unknown prepared-run record %q", fields[0])
	})
	if err != nil {
		return nil, nil, nil, err
	}
	if len(apps) == 0 {
		return nil, nil, nil, errors.New("prepared run contains no applications")
	}
	return apps, steps, details, nil
}

func scanPrepared(path string, visit func([]string) error) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	formatSeen := false
	for scanner.Scan() {
		fields := strings.Split(scanner.Text(), "\t")
		if len(fields) == 2 && fields[0] == "format" {
			if fields[1] != "2" || formatSeen {
				return errors.New("confirm requires prepared-run format 2")
			}
			formatSeen = true
			continue
		}
		if err := visit(fields); err != nil {
			return err
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if !formatSeen {
		return errors.New("prepared-run format is missing")
	}
	return nil
}

func writeSelection(path string, apps []application, steps []planStep) error {
	if path == "" {
		return errors.New("select requires --output")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".selection-*")
	if err != nil {
		return err
	}
	name := file.Name()
	defer os.Remove(name)
	if _, err = fmt.Fprintln(file, "format\t1"); err == nil {
		for _, step := range steps {
			state := "off"
			if step.enabled {
				state = "on"
			}
			_, err = fmt.Fprintf(file, "step\t%s\t%s\n", step.id, state)
			if err != nil {
				break
			}
		}
		for _, app := range apps {
			_, err = fmt.Fprintf(file, "outcome\t%s\t%s\n", app.id, app.outcome)
			if err != nil {
				break
			}
		}
	}
	if closeErr := file.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(name, path)
}

func writeApproval(path, plan string) error {
	content, err := os.ReadFile(plan)
	if err != nil {
		return err
	}
	digest := fmt.Sprintf("%x", sha256.Sum256(content))
	return writeAtomic(path, func(file *os.File) error {
		if _, err := fmt.Fprintln(file, "format\t1"); err != nil {
			return err
		}
		_, err := fmt.Fprintf(file, "digest\t%s\n", digest)
		return err
	})
}

func writeAtomic(path string, fill func(*os.File) error) error {
	if path == "" {
		return errors.New("output path is required")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".dotfiles-tui-*")
	if err != nil {
		return err
	}
	name := file.Name()
	defer os.Remove(name)
	if err = fill(file); err == nil {
		err = file.Close()
	} else {
		_ = file.Close()
	}
	if err != nil {
		return err
	}
	return os.Rename(name, path)
}

func defaultDisplay() string {
	if value := os.Getenv("DOTFILES_TUI_DISPLAY"); value != "" {
		return value
	}
	if os.Getenv("TERM") == "dumb" {
		return "ascii"
	}
	if _, disabled := os.LookupEnv("NO_COLOR"); disabled {
		return "plain"
	}
	return "rich"
}

func parseCommon(args []string) ([]application, []planStep, map[string][]string, int, displayMode, string, bool, error) {
	flags := flag.NewFlagSet("dotfiles-tui", flag.ContinueOnError)
	observations := flags.String("observations", "", "inspection artifact")
	selection := flags.String("selection", "", "desired-outcome artifact")
	width := flags.Int("width", 120, "render width")
	display := flags.String("display", defaultDisplay(), "rich, ascii, or plain")
	output := flags.String("output", "", "confirmed selection output")
	verbose := flags.Bool("verbose", false, "show application evidence and custody details")
	if err := flags.Parse(args); err != nil {
		return nil, nil, nil, 0, "", "", false, err
	}
	if *observations == "" || *selection == "" {
		return nil, nil, nil, 0, "", "", false, errors.New("--observations and --selection are required")
	}
	mode := displayMode(*display)
	if mode != rich && mode != ascii && mode != plain {
		return nil, nil, nil, 0, "", "", false, errors.New("invalid display mode")
	}
	apps, steps, dependencies, err := parseInputs(*observations, *selection)
	return apps, steps, dependencies, *width, mode, *output, *verbose, err
}

type executionEvent struct{ fields []string }
type executionDone struct{ err error }
type executionLog string

type progressModel struct {
	bar            progress.Model
	width, height  int
	total, settled int
	active         map[string]string
	results        []string
	logs           []string
	done           bool
	err            error
	interactive    bool
	stage          string
	display        displayMode
	interrupt      func()
}

func newProgressModel(interactive bool, stage string, interrupt func()) progressModel {
	return progressModel{bar: progress.New(progress.WithDefaultBlend()), active: map[string]string{}, interactive: interactive, stage: stage, display: displayMode(defaultDisplay()), interrupt: interrupt}
}
func (m progressModel) Init() tea.Cmd { return nil }
func (m progressModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.bar.SetWidth(max(10, msg.Width-12))
	case tea.KeyPressMsg:
		if msg.String() == "ctrl+c" && m.interrupt != nil {
			m.interrupt()
			m.logs = append(m.logs, "Cancellation requested; waiting for the active operation to settle.")
		}
	case executionEvent:
		fields := msg.fields
		if len(fields) < 3 || fields[0] != "event" || fields[1] != "1" ||
			(fields[2] == "run-start" && len(fields) != 4) ||
			(fields[2] == "operation-start" && len(fields) != 6) ||
			(fields[2] == "operation-settled" && len(fields) != 7) ||
			(fields[2] == "run-settled" && len(fields) != 6) ||
			(fields[2] != "run-start" && fields[2] != "operation-start" && fields[2] != "operation-settled" && fields[2] != "run-settled") {
			m.err = fmt.Errorf("malformed execution event %q", strings.Join(fields, "\t"))
			return m, nil
		}
		switch fields[2] {
		case "run-start":
			if len(fields) == 4 {
				m.total, _ = strconv.Atoi(fields[3])
			}
		case "operation-start":
			if len(fields) == 6 {
				m.active[fields[3]] = fields[4]
			}
		case "operation-settled":
			if len(fields) == 7 {
				label := m.active[fields[3]]
				delete(m.active, fields[3])
				m.settled, _ = strconv.Atoi(fields[5])
				m.total, _ = strconv.Atoi(fields[6])
				separator := " — "
				if m.display == ascii {
					separator = " - "
				}
				m.results = append(m.results, label+separator+fields[4])
			}
		}
	case executionLog:
		if line := strings.TrimSpace(string(msg)); line != "" {
			m.logs = append(m.logs, line)
			if len(m.logs) > 5 {
				m.logs = m.logs[len(m.logs)-5:]
			}
		}
	case executionDone:
		m.done = true
		if m.err == nil {
			m.err = msg.err
		}
		return m, tea.Quit
	}
	return m, nil
}
func (m progressModel) View() tea.View {
	view := tea.NewView(m.render())
	view.AltScreen = m.interactive
	return view
}
func (m progressModel) render() string {
	width, height := m.width, m.height
	if width <= 0 {
		width = 100
	}
	if height <= 0 {
		height = 30
	}
	separator, activeMarker, settledMarker := " · ", "◐", "●"
	if m.display == ascii {
		separator, activeMarker, settledMarker = " | ", "[~]", "[+]"
	}
	if width < 40 || height < 14 {
		activity := fmt.Sprintf("Working: %d/%d settled", m.settled, m.total)
		return compactContext(m.stage, separator, activity, "", width, height)
	}
	percent := 0.0
	if m.total > 0 {
		percent = float64(m.settled) / float64(m.total)
	}
	var b strings.Builder
	fmt.Fprintln(&b, fit(stageStepper(m.stage, separator), width))
	for _, line := range wrapSegments([]string{"Ensure", "Leave", "Remove"}, separator, width) {
		fmt.Fprintln(&b, line)
	}
	activity := "RUN"
	if m.stage == "plan" {
		activity = "INSPECTING MACHINE"
	}
	fmt.Fprintf(&b, "DOTFILES %s  %d/%d settled\n%s\n\n", activity, m.settled, m.total, m.bar.ViewAs(percent))
	fmt.Fprintln(&b, "ACTIVE")
	if len(m.active) == 0 {
		fmt.Fprintln(&b, "  (none)")
	} else {
		for _, label := range m.active {
			fmt.Fprintf(&b, "  %s %s%sworking\n", activeMarker, label, separator)
		}
	}
	fmt.Fprintln(&b, "\nSETTLED")
	start := max(0, len(m.results)-8)
	for _, result := range m.results[start:] {
		fmt.Fprintf(&b, "  %s %s\n", settledMarker, result)
	}
	waiting := max(0, m.total-m.settled-len(m.active))
	fmt.Fprintf(&b, "\nWAITING\n  %d logical operations\n", waiting)
	if len(m.logs) > 0 {
		fmt.Fprintln(&b, "\nLATEST OUTPUT")
		for _, line := range m.logs {
			fmt.Fprintf(&b, "  %s\n", line)
		}
	}
	if m.done {
		if m.err != nil {
			fmt.Fprintf(&b, "\nRun failed: %v\n", m.err)
		} else {
			fmt.Fprintln(&b, "\nRun settled successfully.")
		}
	}
	lines := strings.Split(strings.TrimSuffix(b.String(), "\n"), "\n")
	if len(lines) > height {
		footer := lines[len(lines)-1:]
		lines = append(lines[:max(0, height-len(footer))], footer...)
	}
	return fitScreen(lines, width, height)
}

func isTerminalFile(file *os.File) bool {
	info, err := file.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

func nonInteractiveProgressEnvironment() []string {
	environment := make([]string, 0, len(os.Environ())+2)
	for _, entry := range os.Environ() {
		if strings.HasPrefix(entry, "TERM=") || strings.HasPrefix(entry, "TERM_PROGRAM=") || strings.HasPrefix(entry, "SSH_TTY=") || strings.HasPrefix(entry, "WT_SESSION=") {
			continue
		}
		environment = append(environment, entry)
	}
	// Bubble Tea v2 queries modes 2026/2027 even when WithInput(nil) prevents
	// it from consuming the terminal's replies. Present a conservative renderer
	// environment for progress-only views; the child command keeps the real one.
	return append(environment, "TERM=vt100", "TERM_PROGRAM=Apple_Terminal", "SSH_TTY=progress-no-input")
}

func executionStage(command []string) string {
	for _, argument := range command {
		if argument == "inspect" {
			return "plan"
		}
	}
	return "run"
}

func runExecution(command []string) error {
	if len(command) == 0 {
		return errors.New("run requires a command after --")
	}
	cmd := exec.Command(command[0], command[1:]...)
	eventReader, eventWriter, err := os.Pipe()
	if err != nil {
		return err
	}
	defer eventReader.Close()
	cmd.ExtraFiles = []*os.File{eventWriter} // The child receives this as file descriptor 3.
	cmd.Env = append(os.Environ(), "DOTFILES_INSTALL_PLAN_EVENTS=1", "DOTFILES_INSTALL_PLAN_EVENT_FD=3")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		eventWriter.Close()
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		eventWriter.Close()
		return err
	}
	interactive := isTerminalFile(os.Stdout)
	interrupt := func() {
		if cmd.Process != nil {
			_ = cmd.Process.Signal(os.Interrupt)
		}
	}
	programOptions := []tea.ProgramOption{tea.WithoutSignalHandler()}
	if !interactive {
		programOptions = append(programOptions, tea.WithInput(nil), tea.WithEnvironment(nonInteractiveProgressEnvironment()))
	}
	program := tea.NewProgram(newProgressModel(interactive, executionStage(command), interrupt), programOptions...)
	if err = cmd.Start(); err != nil {
		eventWriter.Close()
		return err
	}
	_ = eventWriter.Close()
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)
	go func() {
		for received := range signals {
			if cmd.Process != nil {
				_ = cmd.Process.Signal(received)
			}
		}
	}()
	var scanners sync.WaitGroup
	scanners.Add(3)
	scanEvents := func(scanner *bufio.Scanner) {
		defer scanners.Done()
		for scanner.Scan() {
			program.Send(executionEvent{strings.Split(scanner.Text(), "\t")})
		}
	}
	scanLogs := func(scanner *bufio.Scanner) {
		defer scanners.Done()
		for scanner.Scan() {
			program.Send(executionLog(scanner.Text()))
		}
	}
	go scanEvents(bufio.NewScanner(eventReader))
	go scanLogs(bufio.NewScanner(stdout))
	go scanLogs(bufio.NewScanner(stderr))
	go func() { commandErr := cmd.Wait(); scanners.Wait(); program.Send(executionDone{commandErr}) }()
	final, runErr := program.Run()
	if runErr != nil {
		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}
		return runErr
	}
	result := final.(progressModel)
	if result.err != nil || !interactive {
		fmt.Print(result.render())
	}
	return result.err
}

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("usage: dotfiles-tui render|choose|select|confirm|run [options]")
	}
	if args[0] == "run" {
		command := args[1:]
		if len(command) > 0 && command[0] == "--" {
			command = command[1:]
		}
		return runExecution(command)
	}
	if args[0] == "confirm" {
		flags := flag.NewFlagSet("confirm", flag.ContinueOnError)
		plan := flags.String("plan", "", "prepared run")
		output := flags.String("output", "", "approval artifact")
		width := flags.Int("width", 120, "render width")
		display := flags.String("display", defaultDisplay(), "rich, ascii, or plain")
		verbose := flags.Bool("verbose", false, "show application evidence and custody details")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		apps, steps, details, err := parsePrepared(*plan)
		if err != nil {
			return err
		}
		m := model{apps: apps, steps: steps, reviewDetails: details, width: *width, display: displayMode(*display), stage: "review", confirmOnly: true, interactive: true, verbose: *verbose}
		final, err := tea.NewProgram(m).Run()
		if err != nil {
			return err
		}
		result := final.(model)
		if result.cancelled || !result.confirmed {
			return errors.New("confirmation cancelled")
		}
		return writeApproval(*output, *plan)
	}
	apps, steps, dependencies, width, display, output, verbose, err := parseCommon(args[1:])
	if err != nil {
		return err
	}
	m := model{apps: apps, steps: steps, dependencies: dependencies, width: width, display: display, stage: "select", output: output, chooseOnly: args[0] == "choose", interactive: args[0] != "render", verbose: verbose}
	switch args[0] {
	case "render":
		fmt.Print(m.render())
		return nil
	case "choose", "select":
		final, err := tea.NewProgram(m).Run()
		if err != nil {
			return err
		}
		result := final.(model)
		if result.cancelled || !result.confirmed {
			return errors.New("selection cancelled")
		}
		return writeSelection(output, result.apps, result.steps)
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "dotfiles-tui:", err)
		os.Exit(1)
	}
}
