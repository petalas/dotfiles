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
)

type outcome string

const (
	ensure outcome = "ensure"
	leave  outcome = "leave"
	remove outcome = "remove"
	force  outcome = "force"
)

var lanes = []outcome{ensure, leave, remove, force}
var laneTitles = map[outcome]string{ensure: "ENSURE PRESENT", leave: "LEAVE UNCHANGED", remove: "REMOVE", force: "FORCE REMOVAL"}

type planStep struct {
	id, label string
	enabled   bool
}

type application struct {
	id, group, label, availability, presence, custody, policy, exact, force, evidence string
	outcome                                                                           outcome
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
	width, lane, cursor  int
	groupFilter          int
	display              displayMode
	stage, input, notice string
	stepMode             bool
	stepCursor           int
	arm                  int
	output               string
	confirmed, cancelled bool
	chooseOnly           bool
	confirmOnly          bool
}

func parseInputs(observationsPath, selectionPath string) ([]application, []planStep, map[string][]string, error) {
	selected := map[string]outcome{}
	steps := []planStep{}
	dependencies := map[string][]string{}
	if err := scanTSV(selectionPath, func(fields []string) error {
		switch {
		case len(fields) == 3 && fields[0] == "outcome":
			switch outcome(fields[2]) {
			case ensure, leave, remove, force:
				selected[fields[1]] = outcome(fields[2])
			default:
				return fmt.Errorf("invalid desired outcome for %s", fields[1])
			}
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
				exact: fields[6], force: fields[7], group: fields[8], label: fields[9],
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
		m.width = msg.Width
	case tea.KeyPressMsg:
		key := msg.String()
		if key == "ctrl+c" || key == "q" && (m.stage == "select" || (m.confirmOnly && m.stage == "review")) {
			m.cancelled = true
			return m, tea.Quit
		}
		if m.stage == "confirm" {
			return m.updateConfirmation(key)
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
			if m.lane > 0 {
				m.lane--
				m.cursor = 0
			}
		case "right", "l":
			if m.lane < len(lanes)-1 {
				m.lane++
				m.cursor = 0
			}
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
			if m.cursor+1 < len(m.appsInLane(lanes[m.lane])) {
				m.cursor++
			}
		case "e":
			m.setSelectedOutcome(ensure)
		case "u":
			m.setSelectedOutcome(leave)
		case "r":
			m.setSelectedOutcome(remove)
		case "f":
			m.setSelectedOutcome(force)
		case "enter":
			if m.stage == "select" && m.chooseOnly {
				m.confirmed = true
				return m, tea.Quit
			}
			if m.stage == "select" {
				m.stage = "review"
			} else {
				m.beginConfirmation()
			}
		case "esc":
			if m.stage == "review" && m.confirmOnly {
				m.cancelled = true
				return m, tea.Quit
			}
			if m.stage == "review" {
				m.stage = "select"
			}
		}
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
	forces, exact := len(m.appsWithOutcome(force)), len(m.appsWithOutcome(remove))
	count := forces
	if exact > 0 {
		count++
	}
	if forces > 0 {
		count++
	}
	if count == 0 {
		count = 1
	}
	return count
}
func (m model) expectedPhrase() string {
	forces := m.appsWithOutcome(force)
	position := m.arm
	if position < len(forces) {
		return forces[position].label
	}
	position -= len(forces)
	exact := len(m.appsWithOutcome(remove))
	if exact > 0 {
		if position == 0 {
			return fmt.Sprintf("REMOVE %d", exact)
		}
		position--
	}
	if len(forces) > 0 && position == 0 {
		return fmt.Sprintf("FORCE REMOVE %d", len(forces))
	}
	return "START"
}

func (m *model) setSelectedOutcome(next outcome) {
	visible := m.appsInLane(lanes[m.lane])
	if m.cursor >= len(visible) {
		return
	}
	id := visible[m.cursor].id
	for i := range m.apps {
		if m.apps[i].id != id {
			continue
		}
		if m.apps[i].availability == "unavailable" && next != leave {
			m.notice = "Unavailable on this platform"
			return
		}
		if m.apps[i].policy == "required" && next != ensure {
			m.notice = "Removal disabled: required application"
			return
		}
		if (next == remove || next == force) && m.retainedDependent(id) != "" {
			m.notice = "Removal disabled: retained dependent " + m.retainedDependent(id)
			return
		}
		if next == remove && m.apps[i].exact != "enabled" {
			m.notice = "Exact removal disabled: managed custody is required"
			return
		}
		if next == force && m.apps[i].force != "enabled" {
			m.notice = "Force removal disabled: no cleanup recipe"
			return
		}
		m.apps[i].outcome = next
		m.notice = ""
		if next == ensure {
			for _, prerequisite := range m.dependencies[id] {
				m.setOutcomeByID(prerequisite, ensure)
			}
		} else if next == leave {
			for _, prerequisite := range m.dependencies[id] {
				if current := m.appByID(prerequisite); current != nil && (current.outcome == remove || current.outcome == force) {
					m.setOutcomeByID(prerequisite, leave)
				}
			}
		}
		m.lane = laneIndex(next)
		m.cursor = len(m.appsInLane(next)) - 1
		return
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
			if app.outcome != remove && app.outcome != force && app.presence != "absent" {
				return app.label
			}
		}
	}
	return ""
}

func laneIndex(wanted outcome) int {
	for i, candidate := range lanes {
		if candidate == wanted {
			return i
		}
	}
	return 0
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
func (m model) appsInLane(wanted outcome) []application {
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

func (m model) View() tea.View { return tea.NewView(m.render()) }

func (m model) render() string {
	if m.stage == "review" || m.stage == "confirm" {
		return m.renderReview()
	}
	return m.renderLanes()
}

func (m model) renderLanes() string {
	width := m.width
	if width <= 0 {
		width = 120
	}
	group := m.groupFilters()[m.groupFilter]
	managed, reconcile, warnings := 0, 0, 0
	for _, app := range m.apps {
		if app.presence == "present" && app.custody == "managed" {
			managed++
		}
		if app.outcome == ensure && app.presence != "present" {
			reconcile++
		}
		if app.presence == "present" && app.custody == "unverified" {
			warnings++
		}
	}
	header := fmt.Sprintf("DOTFILES  PLAN  |  %d applications  |  group: %s  |  arrows move · tab steps · [/] filter · e/u/r/f choose · enter review\nmanaged %d · reconcile %d · custody warnings %d · exact removals %d · Force removals %d\n", len(m.apps), group, managed, reconcile, warnings, len(m.appsWithOutcome(remove)), len(m.appsWithOutcome(force)))
	if m.notice != "" {
		header += "! " + m.notice + "\n"
	}
	if len(m.steps) > 0 {
		header += "STEPS"
		for i, step := range m.steps {
			mark := " "
			if step.enabled {
				mark = "x"
			}
			cursor := " "
			if m.stepMode && i == m.stepCursor {
				cursor = ">"
			}
			header += fmt.Sprintf("  %s[%s] %s", cursor, mark, step.label)
		}
		header += "\n"
	}
	if width < 90 {
		return header + fmt.Sprintf("Lane %d/4\n", m.lane+1) + m.renderLane(lanes[m.lane], width-2, true) + "\n"
	}
	laneWidth := (width - 5) / 4
	columns := make([]string, 0, 4)
	for i, wanted := range lanes {
		columns = append(columns, m.renderLane(wanted, laneWidth, i == m.lane))
	}
	if m.display == rich {
		return header + lipgloss.JoinHorizontal(lipgloss.Top, columns...) + "\n"
	}
	return header + joinColumns(columns, laneWidth) + "\n"
}

func (m model) renderLane(wanted outcome, width int, active bool) string {
	apps := m.appsInLane(wanted)
	lines := []string{fmt.Sprintf("%s (%d)", laneTitles[wanted], len(apps))}
	for i, app := range apps {
		cursor := "  "
		if active && i == m.cursor {
			cursor = "> "
		}
		lines = append(lines, fit(cursor+m.marker(app)+" "+app.label, width))
		lines = append(lines, fit("  "+app.group+" · "+app.custody, width))
		lines = append(lines, fit("  "+app.evidence, width))
		if app.availability == "unavailable" {
			lines = append(lines, fit("  unavailable on this platform", width))
		} else if dependent := m.retainedDependent(app.id); dependent != "" {
			lines = append(lines, fit("  removal disabled · retained by "+dependent, width))
		} else if app.policy == "required" {
			lines = append(lines, fit("  removal disabled · required", width))
		} else if app.exact != "enabled" && app.force != "enabled" {
			lines = append(lines, fit("  removal disabled · no safe method", width))
		} else if app.exact != "enabled" {
			lines = append(lines, fit("  exact disabled · custody unverified", width))
		}
	}
	if len(apps) == 0 {
		lines = append(lines, "  (empty)")
	}
	content := strings.Join(lines, "\n")
	if m.display != rich {
		return content
	}
	border := lipgloss.Color("8")
	if active {
		border = lipgloss.Color("6")
	}
	return lipgloss.NewStyle().Width(width-3).Padding(0, 1).Border(lipgloss.RoundedBorder()).BorderForeground(border).Render(content)
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
	var b strings.Builder
	fmt.Fprintf(&b, "REVIEW PREPARED RUN\n\nSTEPS\n")
	for _, step := range m.steps {
		state := "off"
		if step.enabled {
			state = "on"
		}
		fmt.Fprintf(&b, "  [%s] %s\n", state, step.label)
	}
	fmt.Fprintln(&b)
	for _, wanted := range lanes {
		apps := m.appsWithOutcome(wanted)
		fmt.Fprintf(&b, "%s (%d)\n", laneTitles[wanted], len(apps))
		for _, app := range apps {
			fmt.Fprintf(&b, "  %s %s — %s\n", m.marker(app), app.label, app.evidence)
		}
	}
	if len(m.reviewDetails) > 0 {
		fmt.Fprintln(&b, "\nMETHODS AND BLOCKERS")
		for _, detail := range m.reviewDetails {
			fmt.Fprintf(&b, "  %s\n", detail)
		}
	}
	if m.stage == "confirm" {
		fmt.Fprintf(&b, "\nType %q to continue:\n> %s", m.expectedPhrase(), m.input)
	} else {
		fmt.Fprint(&b, "\nEnter confirms this review; Esc returns to planning.")
	}
	return b.String()
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
	runes := []rune(value)
	if len(runes) > width {
		if width > 1 {
			return string(runes[:width-1]) + "…"
		}
		return string(runes[:width])
	}
	return value + strings.Repeat(" ", width-len(runes))
}

func parsePrepared(path string) ([]application, []planStep, []string, error) {
	apps := []application{}
	steps := []planStep{}
	details := []string{}
	err := scanPrepared(path, func(fields []string) error {
		if len(fields) == 8 && fields[0] == "app" {
			apps = append(apps, application{id: fields[1], outcome: outcome(fields[2]), policy: fields[3],
				group: fields[4], label: fields[5], presence: fields[6], custody: fields[7], evidence: fields[6] + " · " + fields[7]})
			return nil
		}
		if len(fields) == 5 && fields[0] == "step" {
			steps = append(steps, planStep{id: fields[1], enabled: fields[2] == "on", label: fields[4]})
			return nil
		}
		if len(fields) == 6 && fields[0] == "removal" {
			details = append(details, fmt.Sprintf("%s: %s %s (%s)", fields[2], fields[3], fields[4], fields[1]))
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

func parseCommon(args []string) ([]application, []planStep, map[string][]string, int, displayMode, string, error) {
	flags := flag.NewFlagSet("dotfiles-tui", flag.ContinueOnError)
	observations := flags.String("observations", "", "inspection artifact")
	selection := flags.String("selection", "", "desired-outcome artifact")
	width := flags.Int("width", 120, "render width")
	display := flags.String("display", defaultDisplay(), "rich, ascii, or plain")
	output := flags.String("output", "", "confirmed selection output")
	if err := flags.Parse(args); err != nil {
		return nil, nil, nil, 0, "", "", err
	}
	if *observations == "" || *selection == "" {
		return nil, nil, nil, 0, "", "", errors.New("--observations and --selection are required")
	}
	mode := displayMode(*display)
	if mode != rich && mode != ascii && mode != plain {
		return nil, nil, nil, 0, "", "", errors.New("invalid display mode")
	}
	apps, steps, dependencies, err := parseInputs(*observations, *selection)
	return apps, steps, dependencies, *width, mode, *output, err
}

type executionEvent struct{ fields []string }
type executionDone struct{ err error }
type executionLog string

type progressModel struct {
	bar            progress.Model
	total, settled int
	active         map[string]string
	results        []string
	logs           []string
	done           bool
	err            error
}

func newProgressModel() progressModel {
	return progressModel{bar: progress.New(progress.WithDefaultBlend()), active: map[string]string{}}
}
func (m progressModel) Init() tea.Cmd { return nil }
func (m progressModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.bar.SetWidth(max(20, msg.Width-12))
	case executionEvent:
		fields := msg.fields
		if len(fields) < 3 || fields[0] != "event" || fields[1] != "1" ||
			(fields[2] == "run-start" && len(fields) != 4) ||
			(fields[2] == "operation-start" && len(fields) != 6) ||
			(fields[2] == "operation-settled" && len(fields) != 7) ||
			(fields[2] == "run-settled" && len(fields) != 6) ||
			(fields[2] != "run-start" && fields[2] != "operation-start" && fields[2] != "operation-settled" && fields[2] != "run-settled") {
			m.err = fmt.Errorf("malformed execution event")
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
				m.results = append(m.results, label+" — "+fields[4])
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
func (m progressModel) View() tea.View { return tea.NewView(m.render()) }
func (m progressModel) render() string {
	percent := 0.0
	if m.total > 0 {
		percent = float64(m.settled) / float64(m.total)
	}
	var b strings.Builder
	fmt.Fprintf(&b, "DOTFILES RUN  %d/%d settled\n%s\n\n", m.settled, m.total, m.bar.ViewAs(percent))
	fmt.Fprintln(&b, "ACTIVE")
	if len(m.active) == 0 {
		fmt.Fprintln(&b, "  (none)")
	} else {
		for _, label := range m.active {
			fmt.Fprintf(&b, "  ◐ %s — working\n", label)
		}
	}
	fmt.Fprintln(&b, "\nSETTLED")
	start := max(0, len(m.results)-8)
	for _, result := range m.results[start:] {
		fmt.Fprintf(&b, "  ● %s\n", result)
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
	return b.String()
}

func runExecution(command []string) error {
	if len(command) == 0 {
		return errors.New("run requires a command after --")
	}
	cmd := exec.Command(command[0], command[1:]...)
	cmd.Env = append(os.Environ(), "DOTFILES_INSTALL_PLAN_EVENTS=1")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	program := tea.NewProgram(newProgressModel(), tea.WithInput(nil), tea.WithoutSignalHandler())
	if err = cmd.Start(); err != nil {
		return err
	}
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
	scanners.Add(2)
	scan := func(scanner *bufio.Scanner) {
		defer scanners.Done()
		for scanner.Scan() {
			line := scanner.Text()
			fields := strings.Split(line, "\t")
			if len(fields) > 0 && fields[0] == "event" {
				program.Send(executionEvent{fields})
			} else {
				program.Send(executionLog(line))
			}
		}
	}
	go scan(bufio.NewScanner(stdout))
	go scan(bufio.NewScanner(stderr))
	go func() { commandErr := cmd.Wait(); scanners.Wait(); program.Send(executionDone{commandErr}) }()
	final, runErr := program.Run()
	if runErr != nil {
		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}
		return runErr
	}
	result := final.(progressModel)
	fmt.Print(result.render())
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
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		apps, steps, details, err := parsePrepared(*plan)
		if err != nil {
			return err
		}
		m := model{apps: apps, steps: steps, reviewDetails: details, width: *width, display: displayMode(*display), stage: "review", confirmOnly: true}
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
	apps, steps, dependencies, width, display, output, err := parseCommon(args[1:])
	if err != nil {
		return err
	}
	m := model{apps: apps, steps: steps, dependencies: dependencies, width: width, display: display, stage: "select", output: output, chooseOnly: args[0] == "choose"}
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
