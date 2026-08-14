// Package domain 从 App GameState JSON 中宽容提取运营表字段。
package domain

import (
	"encoding/json"
	"math"
	"strings"
	"time"
)

const (
	DefaultCalorieFloor = 1500
	FemaleCalorieFloor  = 1200
	DefaultMaxDeficit   = 750
	DefaultVisualTheme  = "forge"
)

var (
	sleepNames      = []string{"early", "normal", "night"}
	workNames       = []string{"sedentary", "sometimes", "active"}
	exerciseTimes   = []string{"morning", "afternoon", "evening"}
	characterNames  = []string{"pet", "warrior", "mage", "assassin"}
	difficultyNames = []string{"easy", "normal", "hard"}
	fitnessNames    = []string{"low", "medium", "high"}
	mealSlots       = []string{"breakfast", "lunch", "dinner", "snack"}
)

// Profile 建档身体与偏好（对齐 User.toJson + GameState 顶层字段）
type Profile struct {
	Nickname       *string
	Avatar         *string
	Age            *int
	Gender         *string
	HeightCM       *float64
	WeightKG       *float64
	TargetWeightKG *float64
	BMI            *float64
	SleepType      *string
	WorkType       *string
	ExerciseTime   *string
	CharacterStyle *string
	Difficulty     *string
	FitnessLevel   *string
	PushupCount    *int
	RunDurationMin *int
	WeeklyFreq     *int
	VisualTheme    *string
	SculptLine     *string
	KneeIssue      bool
	WaistIssue     bool
	TargetCal      *int
	CalorieFloor   *int
	Streak         *int
}

// Sculpt 桌面雕塑进度
type Sculpt struct {
	Stage         int
	Progress      float64
	Line          string
	SessionsCount int
	LastSettledAt *time.Time
	Maintenance   string
}

// BodyPoint 某日体重/腰围
type BodyPoint struct {
	RecordedOn time.Time
	WeightKG   *float64
	WaistCM    *float64
}

// MealItem 一餐食物
type MealItem struct {
	EatenAt  time.Time
	Name     string
	Grams    *int
	Calories *int
	MealSlot string
	Source   string
	ClientID string
}

// Session 一节锻炼
type Session struct {
	StartedAt      *time.Time
	EndedAt        *time.Time
	LessonID       string
	LessonName     string
	Mode           string
	Moves          json.RawMessage
	TotalReps      *int
	QualityAvg     *float64
	CaloriesBurned *int
	DamageDealt    *int
	Feel           string
	Settled        bool
	ClientID       string
}

// Extracted 一次快照拆出的规范化数据
type Extracted struct {
	Profile  Profile
	Sculpt   Sculpt
	Metrics  []BodyPoint
	Meals    []MealItem
	Sessions []Session
	Raw      map[string]any
}

// ParseGameState 宽容解析 GameState JSON；缺键不报错。
func ParseGameState(raw json.RawMessage) Extracted {
	out := Extracted{
		Sculpt: Sculpt{Line: "venus", Maintenance: "none"},
		Raw:    map[string]any{},
	}
	if len(raw) == 0 {
		return out
	}
	var root map[string]any
	if err := json.Unmarshal(raw, &root); err != nil {
		return out
	}
	out.Raw = root

	user := asMap(root["user"])
	p := Profile{}
	p.Nickname = strPtr(asString(user["nickname"]))
	p.Avatar = strPtr(asString(user["avatar"]))
	p.Age = intPtr(asInt(user["age"]))
	p.Gender = strPtr(normalizeGender(asString(user["gender"])))
	p.HeightCM = floatPtr(asFloat(user["height"]))
	p.WeightKG = floatPtr(asFloat(user["weight"]))
	p.TargetWeightKG = floatPtr(asFloat(user["targetWeight"]))
	p.BMI = floatPtr(asFloat(user["bmi"]))
	p.SleepType = strPtr(enumName(user["sleepType"], sleepNames))
	p.WorkType = strPtr(enumName(user["workType"], workNames))
	p.ExerciseTime = strPtr(enumName(user["exerciseTime"], exerciseTimes))
	p.CharacterStyle = strPtr(enumName(user["characterStyle"], characterNames))
	p.Difficulty = strPtr(firstNonEmpty(
		enumName(user["difficulty"], difficultyNames),
		enumName(root["difficulty"], difficultyNames),
	))
	p.FitnessLevel = strPtr(firstNonEmpty(
		enumName(user["fitnessLevel"], fitnessNames),
		enumName(root["fitnessLevel"], fitnessNames),
	))
	p.PushupCount = intPtr(asInt(user["pushupCount"]))
	p.RunDurationMin = intPtr(asInt(user["runDuration"]))
	p.WeeklyFreq = intPtr(asInt(user["weeklyFreq"]))
	p.VisualTheme = strPtr(normalizeTheme(asString(root["visualTheme"])))
	p.SculptLine = strPtr(normalizeLine(firstNonEmpty(asString(user["sculptLine"]), asString(root["sculptLine"]))))
	p.KneeIssue = asBool(user["kneeIssue"])
	p.WaistIssue = asBool(user["waistIssue"])
	if tc := asInt(root["targetCal"]); tc != 0 {
		p.TargetCal = intPtr(tc)
	} else if tc := asInt(user["targetCal"]); tc != 0 {
		p.TargetCal = intPtr(tc)
	}
	if st := asInt(root["streak"]); st != 0 || hasKey(root, "streak") {
		p.Streak = intPtr(asInt(root["streak"]))
	} else if hasKey(user, "streak") {
		p.Streak = intPtr(asInt(user["streak"]))
	}
	floor := DefaultCalorieFloor
	if p.Gender != nil && *p.Gender == "female" {
		floor = FemaleCalorieFloor
	}
	if v := asInt(root["calorieFloor"]); v > 0 {
		floor = v
	} else if v := asInt(user["calorieFloor"]); v > 0 {
		floor = v
	}
	p.CalorieFloor = &floor
	if p.BMI == nil || *p.BMI == 0 {
		if p.HeightCM != nil && p.WeightKG != nil && *p.HeightCM > 0 {
			h := *p.HeightCM / 100
			bmi := *p.WeightKG / (h * h)
			p.BMI = &bmi
		}
	}
	out.Profile = p

	sc := Sculpt{
		Stage:         clampInt(asInt(root["sculptStage"]), 0, 7),
		Progress:      clampFloat(asFloat(root["sculptProgress"]), 0, 1),
		Line:          "venus",
		SessionsCount: asInt(root["sculptSettledCount"]),
		Maintenance:   "none",
	}
	if p.SculptLine != nil && *p.SculptLine != "" {
		sc.Line = *p.SculptLine
	}
	if d := asString(root["sculptLastSettledDate"]); d != "" {
		if t, ok := parseDay(d); ok {
			sc.LastSettledAt = &t
		}
	}
	sc.Maintenance = maintenanceFrom(sc.Stage, asBool(root["sculptMaintenance"]))
	out.Sculpt = sc

	day := asString(root["lastDate"])
	baseDay, _ := parseDay(day)
	if baseDay.IsZero() {
		baseDay = time.Now().UTC().Truncate(24 * time.Hour)
	}

	out.Metrics = extractMetrics(root, p.WeightKG)
	out.Meals = extractMeals(root, baseDay)
	out.Sessions = extractSessions(root, baseDay)
	return out
}

func extractMetrics(root map[string]any, fallbackWeight *float64) []BodyPoint {
	byDay := map[string]*BodyPoint{}
	merge := func(day string, w, waist *float64) {
		if day == "" {
			return
		}
		t, ok := parseDay(day)
		if !ok {
			return
		}
		p := byDay[day]
		if p == nil {
			p = &BodyPoint{RecordedOn: t}
			byDay[day] = p
		}
		if w != nil {
			p.WeightKG = w
		}
		if waist != nil {
			p.WaistCM = waist
		}
	}
	if arr, ok := root["weightRecords"].([]any); ok {
		for _, it := range arr {
			m := asMap(it)
			merge(asString(m["date"]), floatPtr(asFloat(m["weight"])), nil)
		}
	}
	if arr, ok := root["waistRecords"].([]any); ok {
		for _, it := range arr {
			m := asMap(it)
			merge(asString(m["date"]), nil, floatPtr(asFloat(m["waistCm"])))
		}
	}
	if last := asString(root["lastDate"]); last != "" && fallbackWeight != nil && *fallbackWeight > 0 {
		if _, exists := byDay[last]; !exists {
			merge(last, fallbackWeight, nil)
		}
	}
	out := make([]BodyPoint, 0, len(byDay))
	for _, p := range byDay {
		out = append(out, *p)
	}
	return out
}

func extractMeals(root map[string]any, day time.Time) []MealItem {
	mealsRaw := root["meals"]
	m := asMap(mealsRaw)
	if len(m) == 0 {
		return nil
	}
	var out []MealItem
	for k, v := range m {
		slot := mealSlotFromKey(k)
		list, ok := v.([]any)
		if !ok {
			continue
		}
		for i, it := range list {
			fm := asMap(it)
			name := asString(fm["name"])
			if name == "" {
				continue
			}
			item := MealItem{
				EatenAt:  day,
				Name:     name,
				Calories: intPtr(asInt(fm["totalCal"])),
				MealSlot: slot,
				Source:   "manual",
				ClientID: "snapshot:meal:" + day.Format("2006-01-02") + ":" + slot + ":" + name + ":" + itoa(i),
			}
			if hasKey(fm, "grams") {
				item.Grams = intPtr(asInt(fm["grams"]))
			}
			out = append(out, item)
		}
	}
	return out
}

func extractSessions(root map[string]any, day time.Time) []Session {
	arr, ok := root["exercises"].([]any)
	if !ok {
		return nil
	}
	out := make([]Session, 0, len(arr))
	for i, it := range arr {
		m := asMap(it)
		name := asString(m["name"])
		if name == "" {
			continue
		}
		ended := day
		if d := asString(m["date"]); d != "" {
			if t, ok := parseDay(d); ok {
				ended = t
			}
		}
		mode := normalizeMode(asString(m["mode"]))
		cal := asInt(m["cal"])
		dmg := asInt(m["damage"])
		id := asString(m["id"])
		if id == "" {
			id = "snapshot:ex:" + ended.Format("2006-01-02") + ":" + name + ":" + itoa(cal) + ":" + itoa(i)
		} else {
			id = "snapshot:ex:" + id
		}
		s := Session{
			EndedAt:        &ended,
			LessonID:       asString(m["id"]),
			LessonName:     name,
			Mode:           mode,
			Moves:          json.RawMessage(`[]`),
			CaloriesBurned: intPtr(cal),
			DamageDealt:    intPtr(dmg),
			Settled:        true,
			ClientID:       id,
		}
		out = append(out, s)
	}
	return out
}

// PatchGameStateJSON 把运营补丁写回 GameState JSON（供 App 下次拉取）。
func PatchGameStateJSON(raw json.RawMessage, patch map[string]any) (json.RawMessage, error) {
	root := map[string]any{}
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &root); err != nil {
			root = map[string]any{}
		}
	}
	user := asMap(root["user"])
	if user == nil {
		user = map[string]any{}
	}
	if v, ok := patch["weight"]; ok {
		user["weight"] = v
		root["user"] = user
	}
	if v, ok := patch["targetWeight"]; ok {
		user["targetWeight"] = v
		root["user"] = user
	}
	if v, ok := patch["sculptLine"]; ok {
		user["sculptLine"] = v
		root["user"] = user
	}
	if v, ok := patch["targetCal"]; ok {
		root["targetCal"] = v
	}
	if v, ok := patch["streak"]; ok {
		root["streak"] = v
		user["streak"] = v
		root["user"] = user
	}
	if v, ok := patch["sculptStage"]; ok {
		root["sculptStage"] = v
	}
	if v, ok := patch["sculptProgress"]; ok {
		root["sculptProgress"] = v
	}
	if v, ok := patch["visualTheme"]; ok {
		root["visualTheme"] = v
	}
	if v, ok := patch["sculptMaintenance"]; ok {
		root["sculptMaintenance"] = v
	}
	return json.Marshal(root)
}

func maintenanceFrom(stage int, flag bool) string {
	switch stage {
	case 5:
		return "polish"
	case 6:
		return "dust"
	case 7:
		return "rebound"
	default:
		if flag {
			return "polish"
		}
		return "none"
	}
}

func normalizeGender(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	switch s {
	case "male", "female", "other":
		return s
	case "0", "m", "男":
		return "male"
	case "1", "f", "女":
		return "female"
	default:
		return s
	}
}

func normalizeTheme(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	switch s {
	case "forge", "sketch", "ink":
		return s
	default:
		if s == "" {
			return ""
		}
		return s
	}
}

func normalizeLine(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	switch s {
	case "david", "venus":
		return s
	default:
		return s
	}
}

func normalizeMode(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	switch {
	case s == "auto" || s == "imu":
		return "imu"
	case strings.HasPrefix(s, "camera"):
		return "camera"
	case s == "manual" || s == "":
		return "manual"
	default:
		return s
	}
}

func NormalizeFeel(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = strings.ReplaceAll(s, "-", "_")
	switch s {
	case "tooeasy", "too_easy":
		return "too_easy"
	case "toohard", "too_hard":
		return "too_hard"
	case "ok", "justright", "just_right":
		return "ok"
	default:
		return s
	}
}

func mealSlotFromKey(k string) string {
	k = strings.TrimSpace(k)
	switch k {
	case "0", "breakfast":
		return "breakfast"
	case "1", "lunch":
		return "lunch"
	case "2", "dinner":
		return "dinner"
	case "3", "snack":
		return "snack"
	}
	if n := atoi(k); n >= 0 && n < len(mealSlots) {
		return mealSlots[n]
	}
	return k
}

func NormalizeMealSlot(s string) string {
	return mealSlotFromKey(s)
}

func enumName(v any, names []string) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return ""
		}
		if n := atoi(s); n >= 0 && n < len(names) && s == itoa(n) {
			return names[n]
		}
		return strings.ToLower(s)
	case float64:
		n := int(t)
		if n >= 0 && n < len(names) {
			return names[n]
		}
	case json.Number:
		n, _ := t.Int64()
		if int(n) >= 0 && int(n) < len(names) {
			return names[int(n)]
		}
	}
	return ""
}

func CalorieFloorForGender(gender string) int {
	if strings.ToLower(gender) == "female" {
		return FemaleCalorieFloor
	}
	return DefaultCalorieFloor
}

func asMap(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

func asString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case json.Number:
		return t.String()
	default:
		return ""
	}
}

func asInt(v any) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	case int64:
		return int(t)
	case json.Number:
		n, _ := t.Int64()
		return int(n)
	case string:
		return atoi(t)
	default:
		return 0
	}
}

func asFloat(v any) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case int:
		return float64(t)
	case int64:
		return float64(t)
	case json.Number:
		n, _ := t.Float64()
		return n
	case string:
		f := 0.0
		_ = json.Unmarshal([]byte(t), &f)
		return f
	default:
		return 0
	}
}

func asBool(v any) bool {
	switch t := v.(type) {
	case bool:
		return t
	case string:
		return t == "true" || t == "1"
	case float64:
		return t != 0
	default:
		return false
	}
}

func hasKey(m map[string]any, k string) bool {
	_, ok := m[k]
	return ok
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func intPtr(n int) *int { return &n }

func floatPtr(f float64) *float64 {
	if f == 0 {
		return nil
	}
	return &f
}

func firstNonEmpty(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}

func parseDay(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, false
	}
	if t, err := time.Parse("2006-01-02", s[:min(len(s), 10)]); err == nil {
		return t, true
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.UTC().Truncate(24 * time.Hour), true
	}
	return time.Time{}, false
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func clampFloat(v, lo, hi float64) float64 {
	return math.Min(hi, math.Max(lo, v))
}

func atoi(s string) int {
	n := 0
	neg := false
	for i, c := range s {
		if i == 0 && c == '-' {
			neg = true
			continue
		}
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
	}
	if neg {
		return -n
	}
	return n
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [16]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
