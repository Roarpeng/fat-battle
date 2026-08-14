package repo

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"fatbattle/backend/internal/domain"
)

// ---------- 档案 ----------

type UserProfile struct {
	UserID         int64      `json:"userId"`
	Nickname       *string    `json:"nickname,omitempty"`
	Avatar         *string    `json:"avatar,omitempty"`
	Age            *int       `json:"age,omitempty"`
	Gender         *string    `json:"gender,omitempty"`
	HeightCM       *float64   `json:"heightCm,omitempty"`
	WeightKG       *float64   `json:"weightKg,omitempty"`
	TargetWeightKG *float64   `json:"targetWeightKg,omitempty"`
	BMI            *float64   `json:"bmi,omitempty"`
	SleepType      *string    `json:"sleepType,omitempty"`
	WorkType       *string    `json:"workType,omitempty"`
	ExerciseTime   *string    `json:"exerciseTime,omitempty"`
	CharacterStyle *string    `json:"characterStyle,omitempty"`
	Difficulty     *string    `json:"difficulty,omitempty"`
	FitnessLevel   *string    `json:"fitnessLevel,omitempty"`
	PushupCount    *int       `json:"pushupCount,omitempty"`
	RunDurationMin *int       `json:"runDurationMin,omitempty"`
	WeeklyFreq     *int       `json:"weeklyFreq,omitempty"`
	VisualTheme    *string    `json:"visualTheme,omitempty"`
	SculptLine     *string    `json:"sculptLine,omitempty"`
	KneeIssue      bool       `json:"kneeIssue"`
	WaistIssue     bool       `json:"waistIssue"`
	TargetCal      *int       `json:"targetCal,omitempty"`
	CalorieFloor   *int       `json:"calorieFloor,omitempty"`
	Streak         int        `json:"streak"`
	LastSeenAt     *time.Time `json:"lastSeenAt,omitempty"`
	UpdatedAt      time.Time  `json:"updatedAt"`
}

func TouchLastSeen(ctx context.Context, pool *pgxpool.Pool, userID int64) {
	if pool == nil {
		return
	}
	_, _ = pool.Exec(ctx, `
		INSERT INTO user_profiles (user_id, last_seen_at, calorie_floor)
		VALUES ($1, NOW(), $2)
		ON CONFLICT (user_id) DO UPDATE SET last_seen_at = NOW()`,
		userID, domain.DefaultCalorieFloor)
}

func EnsureProfile(ctx context.Context, pool *pgxpool.Pool, userID int64, nickname string) error {
	_, err := pool.Exec(ctx, `
		INSERT INTO user_profiles (user_id, nickname, calorie_floor)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO NOTHING`,
		userID, nickname, domain.DefaultCalorieFloor)
	return err
}

func GetProfile(ctx context.Context, pool *pgxpool.Pool, userID int64) (*UserProfile, error) {
	p := UserProfile{UserID: userID}
	err := pool.QueryRow(ctx, `
		SELECT user_id, nickname, avatar, age, gender, height_cm, weight_kg, target_weight_kg, bmi,
		       sleep_type, work_type, exercise_time, character_style, difficulty, fitness_level,
		       pushup_count, run_duration_min, weekly_freq, visual_theme, sculpt_line,
		       knee_issue, waist_issue, target_cal, calorie_floor, COALESCE(streak, 0),
		       last_seen_at, updated_at
		FROM user_profiles WHERE user_id = $1`, userID).Scan(
		&p.UserID, &p.Nickname, &p.Avatar, &p.Age, &p.Gender, &p.HeightCM, &p.WeightKG,
		&p.TargetWeightKG, &p.BMI, &p.SleepType, &p.WorkType, &p.ExerciseTime, &p.CharacterStyle,
		&p.Difficulty, &p.FitnessLevel, &p.PushupCount, &p.RunDurationMin, &p.WeeklyFreq,
		&p.VisualTheme, &p.SculptLine, &p.KneeIssue, &p.WaistIssue, &p.TargetCal, &p.CalorieFloor,
		&p.Streak, &p.LastSeenAt, &p.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if p.CalorieFloor == nil {
		f := domain.DefaultCalorieFloor
		p.CalorieFloor = &f
	}
	return &p, nil
}

func UpsertProfileFromDomain(ctx context.Context, pool *pgxpool.Pool, userID int64, p domain.Profile) error {
	floor := domain.DefaultCalorieFloor
	if p.CalorieFloor != nil && *p.CalorieFloor > 0 {
		floor = *p.CalorieFloor
	} else if p.Gender != nil {
		floor = domain.CalorieFloorForGender(*p.Gender)
	}
	streak := 0
	if p.Streak != nil {
		streak = *p.Streak
	}
	_, err := pool.Exec(ctx, `
		INSERT INTO user_profiles (
			user_id, nickname, avatar, age, gender, height_cm, weight_kg, target_weight_kg, bmi,
			sleep_type, work_type, exercise_time, character_style, difficulty, fitness_level,
			pushup_count, run_duration_min, weekly_freq, visual_theme, sculpt_line,
			knee_issue, waist_issue, target_cal, calorie_floor, streak, last_seen_at
		) VALUES (
			$1,$2,$3,$4,$5,$6,$7,$8,$9,
			$10,$11,$12,$13,$14,$15,
			$16,$17,$18,$19,$20,
			$21,$22,$23,$24,$25, NOW()
		)
		ON CONFLICT (user_id) DO UPDATE SET
			nickname = COALESCE(EXCLUDED.nickname, user_profiles.nickname),
			avatar = COALESCE(EXCLUDED.avatar, user_profiles.avatar),
			age = COALESCE(EXCLUDED.age, user_profiles.age),
			gender = COALESCE(EXCLUDED.gender, user_profiles.gender),
			height_cm = COALESCE(EXCLUDED.height_cm, user_profiles.height_cm),
			weight_kg = COALESCE(EXCLUDED.weight_kg, user_profiles.weight_kg),
			target_weight_kg = COALESCE(EXCLUDED.target_weight_kg, user_profiles.target_weight_kg),
			bmi = COALESCE(EXCLUDED.bmi, user_profiles.bmi),
			sleep_type = COALESCE(EXCLUDED.sleep_type, user_profiles.sleep_type),
			work_type = COALESCE(EXCLUDED.work_type, user_profiles.work_type),
			exercise_time = COALESCE(EXCLUDED.exercise_time, user_profiles.exercise_time),
			character_style = COALESCE(EXCLUDED.character_style, user_profiles.character_style),
			difficulty = COALESCE(EXCLUDED.difficulty, user_profiles.difficulty),
			fitness_level = COALESCE(EXCLUDED.fitness_level, user_profiles.fitness_level),
			pushup_count = COALESCE(EXCLUDED.pushup_count, user_profiles.pushup_count),
			run_duration_min = COALESCE(EXCLUDED.run_duration_min, user_profiles.run_duration_min),
			weekly_freq = COALESCE(EXCLUDED.weekly_freq, user_profiles.weekly_freq),
			visual_theme = COALESCE(EXCLUDED.visual_theme, user_profiles.visual_theme),
			sculpt_line = COALESCE(EXCLUDED.sculpt_line, user_profiles.sculpt_line),
			knee_issue = EXCLUDED.knee_issue,
			waist_issue = EXCLUDED.waist_issue,
			target_cal = COALESCE(EXCLUDED.target_cal, user_profiles.target_cal),
			calorie_floor = COALESCE(EXCLUDED.calorie_floor, user_profiles.calorie_floor, $24),
			streak = CASE WHEN EXCLUDED.streak IS NOT NULL THEN EXCLUDED.streak ELSE user_profiles.streak END,
			last_seen_at = NOW(),
			updated_at = NOW()`,
		userID, p.Nickname, p.Avatar, p.Age, p.Gender, p.HeightCM, p.WeightKG, p.TargetWeightKG, p.BMI,
		p.SleepType, p.WorkType, p.ExerciseTime, p.CharacterStyle, p.Difficulty, p.FitnessLevel,
		p.PushupCount, p.RunDurationMin, p.WeeklyFreq, p.VisualTheme, p.SculptLine,
		p.KneeIssue, p.WaistIssue, p.TargetCal, floor, streak,
	)
	return err
}

// PatchProfile 管理端/PUT /user/me 按出现的字段更新。
func PatchProfile(ctx context.Context, pool *pgxpool.Pool, userID int64, fields map[string]any) error {
	if len(fields) == 0 {
		return nil
	}
	if _, err := pool.Exec(ctx, `
		INSERT INTO user_profiles (user_id, calorie_floor) VALUES ($1, $2)
		ON CONFLICT (user_id) DO NOTHING`, userID, domain.DefaultCalorieFloor); err != nil {
		return err
	}
	col := map[string]string{
		"nickname": "nickname", "avatar": "avatar", "age": "age", "gender": "gender",
		"heightCm": "height_cm", "weightKg": "weight_kg", "targetWeightKg": "target_weight_kg",
		"bmi": "bmi", "sleepType": "sleep_type", "workType": "work_type",
		"exerciseTime": "exercise_time", "characterStyle": "character_style",
		"difficulty": "difficulty", "fitnessLevel": "fitness_level",
		"pushupCount": "pushup_count", "runDurationMin": "run_duration_min",
		"weeklyFreq": "weekly_freq", "visualTheme": "visual_theme", "sculptLine": "sculpt_line",
		"kneeIssue": "knee_issue", "waistIssue": "waist_issue",
		"targetCal": "target_cal", "calorieFloor": "calorie_floor", "streak": "streak",
	}
	set := []string{"updated_at = NOW()"}
	args := []any{}
	for jsonKey, dbCol := range col {
		if v, ok := fields[jsonKey]; ok {
			args = append(args, v)
			set = append(set, dbCol+" = $"+strconv.Itoa(len(args)))
		}
	}
	if len(args) == 0 {
		return nil
	}
	args = append(args, userID)
	_, err := pool.Exec(ctx,
		`UPDATE user_profiles SET `+strings.Join(set, ", ")+` WHERE user_id = $`+strconv.Itoa(len(args)),
		args...)
	return err
}

// ---------- 雕塑 ----------

type SculptRow struct {
	UserID        int64      `json:"userId"`
	Stage         int        `json:"stage"`
	Progress      float64    `json:"progress"`
	Line          string     `json:"line"`
	SessionsCount int        `json:"sessionsCount"`
	LastSettledAt *time.Time `json:"lastSettledAt,omitempty"`
	Maintenance   string     `json:"maintenance"`
	UpdatedAt     time.Time  `json:"updatedAt"`
}

func GetSculpt(ctx context.Context, pool *pgxpool.Pool, userID int64) (*SculptRow, error) {
	var r SculptRow
	err := pool.QueryRow(ctx, `
		SELECT user_id, stage, progress, line, sessions_count, last_settled_at, maintenance, updated_at
		FROM sculpt_progress WHERE user_id = $1`, userID).Scan(
		&r.UserID, &r.Stage, &r.Progress, &r.Line, &r.SessionsCount, &r.LastSettledAt, &r.Maintenance, &r.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &r, nil
}

func UpsertSculpt(ctx context.Context, pool *pgxpool.Pool, userID int64, s domain.Sculpt) error {
	line := s.Line
	if line == "" {
		line = "venus"
	}
	maint := s.Maintenance
	if maint == "" {
		maint = "none"
	}
	_, err := pool.Exec(ctx, `
		INSERT INTO sculpt_progress (user_id, stage, progress, line, sessions_count, last_settled_at, maintenance)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (user_id) DO UPDATE SET
			stage = EXCLUDED.stage,
			progress = EXCLUDED.progress,
			line = EXCLUDED.line,
			sessions_count = EXCLUDED.sessions_count,
			last_settled_at = COALESCE(EXCLUDED.last_settled_at, sculpt_progress.last_settled_at),
			maintenance = EXCLUDED.maintenance,
			updated_at = NOW()`,
		userID, s.Stage, s.Progress, line, s.SessionsCount, s.LastSettledAt, maint)
	return err
}

func PatchSculpt(ctx context.Context, pool *pgxpool.Pool, userID int64, stage *int, line *string, progress *float64, maint *string) error {
	_, err := pool.Exec(ctx, `
		INSERT INTO sculpt_progress (user_id, stage, line, progress, maintenance)
		VALUES ($1, COALESCE($2,0), COALESCE($3,'venus'), COALESCE($4,0), COALESCE($5,'none'))
		ON CONFLICT (user_id) DO UPDATE SET
			stage = COALESCE($2, sculpt_progress.stage),
			line = COALESCE($3, sculpt_progress.line),
			progress = COALESCE($4, sculpt_progress.progress),
			maintenance = COALESCE($5, sculpt_progress.maintenance),
			updated_at = NOW()`,
		userID, stage, line, progress, maint)
	return err
}

// ---------- 体测 / 锻炼 / 饮食 ----------

type BodyMetric struct {
	ID         int64     `json:"id"`
	UserID     int64     `json:"userId"`
	RecordedOn string    `json:"recordedOn"`
	WeightKG   *float64  `json:"weightKg,omitempty"`
	WaistCM    *float64  `json:"waistCm,omitempty"`
	Source     string    `json:"source"`
	CreatedAt  time.Time `json:"createdAt"`
}

func UpsertBodyMetric(ctx context.Context, pool *pgxpool.Pool, userID int64, on time.Time, weight, waist *float64, source string) error {
	if source == "" {
		source = "app"
	}
	day := on.UTC().Format("2006-01-02")
	_, err := pool.Exec(ctx, `
		INSERT INTO body_metrics (user_id, recorded_on, weight_kg, waist_cm, source)
		VALUES ($1, $2::date, $3, $4, $5)
		ON CONFLICT (user_id, recorded_on) DO UPDATE SET
			weight_kg = COALESCE(EXCLUDED.weight_kg, body_metrics.weight_kg),
			waist_cm = COALESCE(EXCLUDED.waist_cm, body_metrics.waist_cm),
			source = EXCLUDED.source`,
		userID, day, weight, waist, source)
	return err
}

type ExerciseSession struct {
	ID             int64           `json:"id"`
	UserID         int64           `json:"userId"`
	StartedAt      *time.Time      `json:"startedAt,omitempty"`
	EndedAt        *time.Time      `json:"endedAt,omitempty"`
	LessonID       *string         `json:"lessonId,omitempty"`
	LessonName     *string         `json:"lessonName,omitempty"`
	Mode           *string         `json:"mode,omitempty"`
	Moves          json.RawMessage `json:"moves"`
	TotalReps      *int            `json:"totalReps,omitempty"`
	QualityAvg     *float64        `json:"qualityAvg,omitempty"`
	CaloriesBurned *int            `json:"caloriesBurned,omitempty"`
	DamageDealt    *int            `json:"damageDealt,omitempty"`
	Feel           *string         `json:"feel,omitempty"`
	Settled        bool            `json:"settled"`
	CreatedAt      time.Time       `json:"createdAt"`
}

func InsertSession(ctx context.Context, pool *pgxpool.Pool, userID int64, s domain.Session) error {
	moves := s.Moves
	if len(moves) == 0 {
		moves = json.RawMessage(`[]`)
	}
	var feel *string
	if s.Feel != "" {
		f := domain.NormalizeFeel(s.Feel)
		feel = &f
	}
	_, err := pool.Exec(ctx, `
		INSERT INTO exercise_sessions (
			user_id, started_at, ended_at, lesson_id, lesson_name, mode, moves,
			total_reps, quality_avg, calories_burned, damage_dealt, feel, settled, client_event_id
		)
		SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14
		WHERE $14::text IS NULL OR NOT EXISTS (
			SELECT 1 FROM exercise_sessions WHERE user_id = $1 AND client_event_id = $14
		)`,
		userID, s.StartedAt, s.EndedAt, nilIfEmpty(s.LessonID), nilIfEmpty(s.LessonName),
		nilIfEmpty(s.Mode), []byte(moves), s.TotalReps, s.QualityAvg, s.CaloriesBurned,
		s.DamageDealt, feel, s.Settled, nilIfEmpty(s.ClientID),
	)
	return err
}

type MealLog struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"userId"`
	EatenAt   time.Time `json:"eatenAt"`
	Name      string    `json:"name"`
	Grams     *int      `json:"grams,omitempty"`
	Calories  *int      `json:"calories,omitempty"`
	MealSlot  *string   `json:"mealSlot,omitempty"`
	Source    string    `json:"source"`
	CreatedAt time.Time `json:"createdAt"`
}

func InsertMeal(ctx context.Context, pool *pgxpool.Pool, userID int64, m domain.MealItem) error {
	src := m.Source
	if src == "" {
		src = "manual"
	}
	slot := domain.NormalizeMealSlot(m.MealSlot)
	eaten := m.EatenAt
	if eaten.IsZero() {
		eaten = time.Now().UTC()
	}
	_, err := pool.Exec(ctx, `
		INSERT INTO meal_logs (user_id, eaten_at, name, grams, calories, meal_slot, source, client_event_id)
		SELECT $1,$2,$3,$4,$5,$6,$7,$8
		WHERE $8::text IS NULL OR NOT EXISTS (
			SELECT 1 FROM meal_logs WHERE user_id = $1 AND client_event_id = $8
		)`,
		userID, eaten, m.Name, m.Grams, m.Calories, nilIfEmpty(slot), src, nilIfEmpty(m.ClientID),
	)
	return err
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// ---------- 流水 ----------

type ProgressEvent struct {
	ID        int64           `json:"id"`
	UserID    int64           `json:"userId"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	CreatedAt time.Time       `json:"createdAt"`
}

func InsertProgressEvent(ctx context.Context, pool *pgxpool.Pool, userID int64, typ string, payload json.RawMessage, at time.Time) (int64, error) {
	if len(payload) == 0 {
		payload = json.RawMessage(`{}`)
	}
	if at.IsZero() {
		at = time.Now().UTC()
	}
	var id int64
	err := pool.QueryRow(ctx, `
		INSERT INTO progress_events (user_id, type, payload_json, created_at)
		VALUES ($1,$2,$3::jsonb,$4) RETURNING id`,
		userID, typ, []byte(payload), at).Scan(&id)
	return id, err
}

func ListProgressEvents(ctx context.Context, pool *pgxpool.Pool, userID int64, from, to *time.Time, typ string, limit int) ([]ProgressEvent, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	q := `SELECT id, user_id, type, payload_json, created_at FROM progress_events WHERE user_id = $1`
	args := []any{userID}
	if typ != "" {
		args = append(args, typ)
		q += ` AND type = $` + strconv.Itoa(len(args))
	}
	if from != nil {
		args = append(args, *from)
		q += ` AND created_at >= $` + strconv.Itoa(len(args))
	}
	if to != nil {
		args = append(args, *to)
		q += ` AND created_at <= $` + strconv.Itoa(len(args))
	}
	args = append(args, limit)
	q += ` ORDER BY created_at DESC LIMIT $` + strconv.Itoa(len(args))
	rows, err := pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]ProgressEvent, 0)
	for rows.Next() {
		var e ProgressEvent
		if err := rows.Scan(&e.ID, &e.UserID, &e.Type, &e.Payload, &e.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, e)
	}
	return items, rows.Err()
}

func ListSessions(ctx context.Context, pool *pgxpool.Pool, userID int64, from, to *time.Time, limit int) ([]ExerciseSession, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := `SELECT id, user_id, started_at, ended_at, lesson_id, lesson_name, mode, moves,
		total_reps, quality_avg, calories_burned, damage_dealt, feel, settled, created_at
		FROM exercise_sessions WHERE 1=1`
	args := []any{}
	if userID > 0 {
		args = append(args, userID)
		q += ` AND user_id = $` + strconv.Itoa(len(args))
	}
	if from != nil {
		args = append(args, *from)
		q += ` AND COALESCE(ended_at, started_at, created_at) >= $` + strconv.Itoa(len(args))
	}
	if to != nil {
		args = append(args, *to)
		q += ` AND COALESCE(ended_at, started_at, created_at) <= $` + strconv.Itoa(len(args))
	}
	args = append(args, limit)
	q += ` ORDER BY COALESCE(ended_at, started_at, created_at) DESC LIMIT $` + strconv.Itoa(len(args))
	rows, err := pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]ExerciseSession, 0)
	for rows.Next() {
		var s ExerciseSession
		if err := rows.Scan(&s.ID, &s.UserID, &s.StartedAt, &s.EndedAt, &s.LessonID, &s.LessonName,
			&s.Mode, &s.Moves, &s.TotalReps, &s.QualityAvg, &s.CaloriesBurned, &s.DamageDealt,
			&s.Feel, &s.Settled, &s.CreatedAt); err != nil {
			return nil, err
		}
		if len(s.Moves) == 0 {
			s.Moves = json.RawMessage(`[]`)
		}
		items = append(items, s)
	}
	return items, rows.Err()
}

func ListMeals(ctx context.Context, pool *pgxpool.Pool, userID int64, from, to *time.Time, limit int) ([]MealLog, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := `SELECT id, user_id, eaten_at, name, grams, calories, meal_slot, source, created_at
		FROM meal_logs WHERE 1=1`
	args := []any{}
	if userID > 0 {
		args = append(args, userID)
		q += ` AND user_id = $` + strconv.Itoa(len(args))
	}
	if from != nil {
		args = append(args, *from)
		q += ` AND eaten_at >= $` + strconv.Itoa(len(args))
	}
	if to != nil {
		args = append(args, *to)
		q += ` AND eaten_at <= $` + strconv.Itoa(len(args))
	}
	args = append(args, limit)
	q += ` ORDER BY eaten_at DESC LIMIT $` + strconv.Itoa(len(args))
	rows, err := pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]MealLog, 0)
	for rows.Next() {
		var m MealLog
		if err := rows.Scan(&m.ID, &m.UserID, &m.EatenAt, &m.Name, &m.Grams, &m.Calories, &m.MealSlot, &m.Source, &m.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, m)
	}
	return items, rows.Err()
}

func ListMetrics(ctx context.Context, pool *pgxpool.Pool, userID int64, limit int) ([]BodyMetric, error) {
	if limit <= 0 || limit > 200 {
		limit = 60
	}
	rows, err := pool.Query(ctx, `
		SELECT id, user_id, recorded_on::text, weight_kg, waist_cm, source, created_at
		FROM body_metrics WHERE user_id = $1
		ORDER BY recorded_on DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]BodyMetric, 0)
	for rows.Next() {
		var m BodyMetric
		if err := rows.Scan(&m.ID, &m.UserID, &m.RecordedOn, &m.WeightKG, &m.WaistCM, &m.Source, &m.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, m)
	}
	return items, rows.Err()
}

// ---------- 摘要 ----------

type ProgressSummary struct {
	Range         string   `json:"range"`
	KcalIn        int      `json:"kcalIn"`
	KcalOut       int      `json:"kcalOut"`
	Sessions      int      `json:"sessions"`
	Meals         int      `json:"meals"`
	Streak        int      `json:"streak"`
	WeightDeltaKg *float64 `json:"weightDeltaKg,omitempty"`
	SculptStage   int      `json:"sculptStage"`
}

func GetSummary(ctx context.Context, pool *pgxpool.Pool, userID int64, rng string) (*ProgressSummary, error) {
	days := 7
	if rng == "30d" {
		days = 30
	}
	sum := &ProgressSummary{Range: rng}
	since := time.Now().UTC().Add(-time.Duration(days) * 24 * time.Hour)
	_ = pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(calories),0), COUNT(*) FROM meal_logs
		WHERE user_id=$1 AND eaten_at >= $2`, userID, since).Scan(&sum.KcalIn, &sum.Meals)
	_ = pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(calories_burned),0), COUNT(*) FROM exercise_sessions
		WHERE user_id=$1 AND COALESCE(ended_at, started_at, created_at) >= $2`, userID, since).Scan(&sum.KcalOut, &sum.Sessions)
	_ = pool.QueryRow(ctx, `SELECT COALESCE(streak,0) FROM user_profiles WHERE user_id=$1`, userID).Scan(&sum.Streak)
	_ = pool.QueryRow(ctx, `SELECT COALESCE(stage,0) FROM sculpt_progress WHERE user_id=$1`, userID).Scan(&sum.SculptStage)

	var first, last *float64
	_ = pool.QueryRow(ctx, `
		SELECT (SELECT weight_kg FROM body_metrics WHERE user_id=$1 AND recorded_on >= $2::date AND weight_kg IS NOT NULL ORDER BY recorded_on ASC LIMIT 1),
		       (SELECT weight_kg FROM body_metrics WHERE user_id=$1 AND recorded_on >= $2::date AND weight_kg IS NOT NULL ORDER BY recorded_on DESC LIMIT 1)`,
		userID, since.Format("2006-01-02")).Scan(&first, &last)
	if first != nil && last != nil {
		d := *last - *first
		sum.WeightDeltaKg = &d
	}
	return sum, nil
}

// ---------- 设置 ----------

var publicSettingKeys = map[string]string{
	"calorie_floor":             "calorieFloor",
	"max_daily_deficit":         "maxDailyDeficit",
	"coach_enabled":             "coachEnabled",
	"food_recognize_enabled":    "foodRecognizeEnabled",
	"default_visual_theme":      "defaultVisualTheme",
	"sculpt_session_thresholds": "sculptSessionThresholds",
}

func PublicSettingKeys() map[string]string { return publicSettingKeys }

func GetAllSettings(ctx context.Context, pool *pgxpool.Pool) (map[string]json.RawMessage, error) {
	rows, err := pool.Query(ctx, `SELECT key, value FROM app_settings`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]json.RawMessage{}
	for rows.Next() {
		var k string
		var v []byte
		if err := rows.Scan(&k, &v); err != nil {
			return nil, err
		}
		out[k] = json.RawMessage(v)
	}
	return out, rows.Err()
}

func GetPublicSettings(ctx context.Context, pool *pgxpool.Pool) (map[string]any, error) {
	out := DefaultPublicSettings()
	if pool == nil {
		return out, nil
	}
	all, err := GetAllSettings(ctx, pool)
	if err != nil {
		return out, err
	}
	for k, camel := range publicSettingKeys {
		if raw, ok := all[k]; ok {
			var v any
			if json.Unmarshal(raw, &v) == nil {
				out[camel] = v
			}
		}
	}
	return out, nil
}

func DefaultPublicSettings() map[string]any {
	return map[string]any{
		"calorieFloor":            domain.DefaultCalorieFloor,
		"maxDailyDeficit":         domain.DefaultMaxDeficit,
		"coachEnabled":            true,
		"foodRecognizeEnabled":    true,
		"defaultVisualTheme":      domain.DefaultVisualTheme,
		"sculptSessionThresholds": []int{3, 10, 21, 30},
	}
}

func PutSettings(ctx context.Context, pool *pgxpool.Pool, kv map[string]json.RawMessage) error {
	for k, v := range kv {
		if _, err := pool.Exec(ctx, `
			INSERT INTO app_settings (key, value) VALUES ($1, $2::jsonb)
			ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`,
			k, []byte(v)); err != nil {
			return err
		}
	}
	return nil
}

func IsSecretSettingKey(k string) bool {
	lk := strings.ToLower(k)
	for _, n := range []string{"key", "secret", "token", "password", "passwd"} {
		if strings.Contains(lk, n) {
			return true
		}
	}
	return false
}

// ---------- 审计 ----------

type AuditRow struct {
	ID            int64           `json:"id"`
	ActorID       *int64          `json:"actorId,omitempty"`
	ActorUsername string          `json:"actorUsername"`
	Action        string          `json:"action"`
	TargetUserID  *int64          `json:"targetUserId,omitempty"`
	Before        json.RawMessage `json:"before,omitempty"`
	After         json.RawMessage `json:"after,omitempty"`
	CreatedAt     time.Time       `json:"createdAt"`
}

func WriteAudit(ctx context.Context, pool *pgxpool.Pool, actorID int64, actor, action string, target *int64, before, after any) {
	if pool == nil {
		return
	}
	var b, a []byte
	if before != nil {
		b, _ = json.Marshal(before)
	}
	if after != nil {
		a, _ = json.Marshal(after)
	}
	_, _ = pool.Exec(ctx, `
		INSERT INTO admin_audit_log (actor_id, actor_username, action, target_user_id, before_json, after_json)
		VALUES ($1,$2,$3,$4,$5::jsonb,$6::jsonb)`,
		actorID, actor, action, target, b, a)
}

func ListAudit(ctx context.Context, pool *pgxpool.Pool, target *int64, limit int) ([]AuditRow, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := `SELECT id, actor_id, COALESCE(actor_username,''), action, target_user_id, before_json, after_json, created_at
		FROM admin_audit_log`
	args := []any{}
	if target != nil {
		args = append(args, *target)
		q += ` WHERE target_user_id = $1`
	}
	args = append(args, limit)
	q += ` ORDER BY created_at DESC LIMIT $` + strconv.Itoa(len(args))
	rows, err := pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]AuditRow, 0)
	for rows.Next() {
		var r AuditRow
		if err := rows.Scan(&r.ID, &r.ActorID, &r.ActorUsername, &r.Action, &r.TargetUserID, &r.Before, &r.After, &r.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, r)
	}
	return items, rows.Err()
}

// ---------- 统计 ----------

type OpsStats struct {
	DBOk          bool `json:"dbOk"`
	Users         int  `json:"users"`
	DAU           int  `json:"dau"`
	SessionsToday int  `json:"sessionsToday"`
	MealsToday    int  `json:"mealsToday"`
	LLMConfigs    int  `json:"llmConfigs"`
}

func GetOpsStats(ctx context.Context, pool *pgxpool.Pool) OpsStats {
	s := OpsStats{DBOk: pool != nil}
	if pool == nil {
		return s
	}
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE deleted_at IS NULL`).Scan(&s.Users)
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM user_profiles WHERE last_seen_at > NOW() - INTERVAL '24 hours'`).Scan(&s.DAU)
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM exercise_sessions WHERE COALESCE(ended_at, started_at, created_at)::date = CURRENT_DATE`).Scan(&s.SessionsToday)
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM meal_logs WHERE eaten_at::date = CURRENT_DATE`).Scan(&s.MealsToday)
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM llm_configs`).Scan(&s.LLMConfigs)
	return s
}

// ---------- 快照拆表 ----------

// RefreshFromSnapshot 把 GameState 拆进档案/雕塑/体测，并尽力补餐食与锻炼（幂等）。
func RefreshFromSnapshot(ctx context.Context, pool *pgxpool.Pool, userID int64, state json.RawMessage) {
	if pool == nil || len(state) == 0 {
		return
	}
	ex := domain.ParseGameState(state)
	_ = UpsertProfileFromDomain(ctx, pool, userID, ex.Profile)
	_ = UpsertSculpt(ctx, pool, userID, ex.Sculpt)
	for _, m := range ex.Metrics {
		_ = UpsertBodyMetric(ctx, pool, userID, m.RecordedOn, m.WeightKG, m.WaistCM, "app")
	}
	for _, meal := range ex.Meals {
		_ = InsertMeal(ctx, pool, userID, meal)
	}
	for _, sess := range ex.Sessions {
		_ = InsertSession(ctx, pool, userID, sess)
	}
}

// FanOutEvent 把一条流水写入对应规范化表。
func FanOutEvent(ctx context.Context, pool *pgxpool.Pool, userID int64, typ string, at time.Time, payload json.RawMessage, clientID string) error {
	var p map[string]any
	_ = json.Unmarshal(payload, &p)
	if p == nil {
		p = map[string]any{}
	}
	switch strings.ToLower(typ) {
	case "meal":
		m := domain.MealItem{
			EatenAt:  at,
			Name:     asStr(p["name"]),
			Calories: asIntPtr(p["calories"]),
			Grams:    asIntPtr(p["grams"]),
			MealSlot: domain.NormalizeMealSlot(asStr(p["mealSlot"])),
			Source:   firstStr(asStr(p["source"]), "manual"),
			ClientID: clientID,
		}
		if m.Name == "" {
			return nil
		}
		return InsertMeal(ctx, pool, userID, m)
	case "exercise":
		s := domain.Session{
			LessonID:       asStr(p["lessonId"]),
			LessonName:     firstStr(asStr(p["lessonName"]), asStr(p["name"])),
			Mode:           asStr(p["mode"]),
			Feel:           domain.NormalizeFeel(asStr(p["feel"])),
			Settled:        asBool(p["settled"]),
			ClientID:       clientID,
			CaloriesBurned: asIntPtr(p["caloriesBurned"], p["calories"], p["cal"]),
			DamageDealt:    asIntPtr(p["damageDealt"], p["damage"]),
			TotalReps:      asIntPtr(p["totalReps"], p["reps"]),
			QualityAvg:     asFloatPtr(p["qualityAvg"], p["quality"]),
		}
		if t := asTime(p["startedAt"]); t != nil {
			s.StartedAt = t
		}
		if t := asTime(p["endedAt"]); t != nil {
			s.EndedAt = t
		} else if !at.IsZero() {
			s.EndedAt = &at
		}
		if mv, ok := p["moves"]; ok {
			b, _ := json.Marshal(mv)
			s.Moves = b
		}
		if s.LessonName == "" && s.LessonID == "" {
			return nil
		}
		return InsertSession(ctx, pool, userID, s)
	case "weight":
		on := at
		if t := asTime(p["recordedOn"]); t != nil {
			on = *t
		}
		return UpsertBodyMetric(ctx, pool, userID, on, asFloatPtr(p["weightKg"], p["weight"]), asFloatPtr(p["waistCm"]), firstStr(asStr(p["source"]), "app"))
	case "sculpt_settle":
		sc := domain.Sculpt{
			Stage:         asInt(p["stage"]),
			Progress:      asFloat(p["progress"]),
			Line:          firstStr(asStr(p["line"]), "venus"),
			SessionsCount: asInt(p["sessionsCount"]),
			Maintenance:   firstStr(asStr(p["maintenance"]), "none"),
			LastSettledAt: &at,
		}
		if sc.Stage == 0 && sc.Progress == 0 && sc.SessionsCount == 0 {
			// 仍写入结算时间
		}
		return UpsertSculpt(ctx, pool, userID, sc)
	case "battle":
		return nil
	default:
		return nil
	}
}

func asStr(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func firstStr(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}

func asInt(v any) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	case json.Number:
		n, _ := t.Int64()
		return int(n)
	default:
		return 0
	}
}

func asIntPtr(vs ...any) *int {
	for _, v := range vs {
		if v == nil {
			continue
		}
		n := asInt(v)
		return &n
	}
	return nil
}

func asFloat(v any) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case int:
		return float64(t)
	default:
		return 0
	}
}

func asFloatPtr(vs ...any) *float64 {
	for _, v := range vs {
		if v == nil {
			continue
		}
		f := asFloat(v)
		return &f
	}
	return nil
}

func asBool(v any) bool {
	b, ok := v.(bool)
	return ok && b
}

func asTime(v any) *time.Time {
	s, ok := v.(string)
	if !ok || s == "" {
		return nil
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return &t
	}
	if t, err := time.Parse("2006-01-02", s); err == nil {
		return &t
	}
	return nil
}
