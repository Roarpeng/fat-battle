package api

import (
	"strings"
	"testing"
)

func TestClampCalorieFloor(t *testing.T) {
	if got := clampCalorieFloor(0); got != coachDefaultFloor {
		t.Fatalf("zero -> %d, want %d", got, coachDefaultFloor)
	}
	if got := clampCalorieFloor(800); got != coachDefaultFloor {
		t.Fatalf("below absolute min -> %d, want %d", got, coachDefaultFloor)
	}
	if got := clampCalorieFloor(1200); got != 1200 {
		t.Fatalf("female floor kept, got %d", got)
	}
	if got := clampCalorieFloor(1500); got != 1500 {
		t.Fatalf("male floor kept, got %d", got)
	}
	if got := clampCalorieFloor(9000); got != 2500 {
		t.Fatalf("too high clamped, got %d", got)
	}
}

func TestFilterCoachReplyBlocksHarmfulAdvice(t *testing.T) {
	floor := 1500
	cases := []struct {
		name    string
		reply   string
		blocked bool
	}{
		{"ok remaining", "今天预算还剩 420 kcal，蛋白质再补一块鸡胸就稳。", false},
		{"purge", "吃完催吐就不会长胖。", true},
		{"laxative", "可以吃点泻药把热量排掉。", true},
		{"fasting", "惩罚性禁食一天，怪物就死了。", true},
		{"skip meals boss", "跳过晚餐去打 Boss 吧。", true},
		{"skip breakfast", "不吃早餐打怪更有效。", true},
		{"change goal", "把目标改成 800 千卡。", true},
		{"below floor daily", "每天只吃 800 千卡就能瘦。", true},
		{"meal estimate ok", "这顿红烧肉大约 350 kcal，按 120g 记。", false},
		{"empty", "", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, filtered := filterCoachReply(tc.reply, floor)
			if filtered != tc.blocked {
				t.Fatalf("filtered=%v want %v for %q", filtered, tc.blocked, tc.reply)
			}
		})
	}
}

func TestFilterCoachReplyFallbackMentionsFloor(t *testing.T) {
	safe, filtered := filterCoachReply("绝食三天打怪", 1500)
	if !filtered {
		t.Fatal("expected filter")
	}
	if !strings.Contains(safe, "1500") {
		t.Fatalf("fallback should mention floor, got %q", safe)
	}
	if strings.Contains(safe, "跳过正餐去打怪") && strings.Contains(safe, "建议你") {
		t.Fatal("fallback should not recommend the forbidden action")
	}
}

func TestParseCoachOutputJSON(t *testing.T) {
	content := "```json\n{\"reply\":\"还剩 300 kcal\",\"proposedLogs\":[{\"name\":\"鸡胸肉\",\"grams\":120,\"caloriePer100g\":165,\"meal\":\"lunch\"}]}\n```"
	reply, logs := parseCoachOutput(content)
	if reply != "还剩 300 kcal" {
		t.Fatalf("reply=%q", reply)
	}
	if len(logs) != 1 || logs[0].Name != "鸡胸肉" || logs[0].Grams != 120 {
		t.Fatalf("logs=%+v", logs)
	}
}

func TestParseCoachOutputPlainText(t *testing.T) {
	reply, logs := parseCoachOutput("今天预算还剩 200 kcal。")
	if reply != "今天预算还剩 200 kcal。" {
		t.Fatalf("reply=%q", reply)
	}
	if logs != nil {
		t.Fatalf("unexpected logs %+v", logs)
	}
}

func TestSanitizeProposedLogs(t *testing.T) {
	logs := sanitizeProposedLogs([]coachProposedLog{
		{Name: "  ", Grams: 100, CaloriePer100g: 100, Meal: "lunch"},
		{Name: "米饭", Grams: -1, CaloriePer100g: 116, Meal: "weird"},
		{Name: "鸡胸", Grams: 99999, CaloriePer100g: 9999, Meal: "dinner"},
		{Name: "豆腐", Grams: 80, CaloriePer100g: 70, Meal: "snack"},
		{Name: "多余", Grams: 10, CaloriePer100g: 10, Meal: "lunch"},
	})
	if len(logs) != 3 {
		t.Fatalf("cap 3, got %d", len(logs))
	}
	if logs[0].Grams != 100 || logs[0].Meal != "lunch" {
		t.Fatalf("defaults %+v", logs[0])
	}
	if logs[1].Grams != 2000 || logs[1].CaloriePer100g != 900 {
		t.Fatalf("clamped %+v", logs[1])
	}
}

func TestSanitizeHistory(t *testing.T) {
	hist := make([]coachChatMessage, 0, 12)
	for i := 0; i < 12; i++ {
		hist = append(hist, coachChatMessage{Role: "user", Content: "x"})
	}
	hist = append(hist, coachChatMessage{Role: "system", Content: "nope"})
	got := sanitizeHistory(hist)
	if len(got) != coachMaxHistory {
		t.Fatalf("len=%d", len(got))
	}
}

func TestCoachSystemPromptForbidsSilentLog(t *testing.T) {
	p := coachSystemPrompt(1500, 1800)
	for _, needle := range []string{"不能声称已经记入", "安全下限=1500", "工坊目标=1800", "跳过正餐"} {
		if !strings.Contains(p, needle) {
			t.Fatalf("prompt missing %q", needle)
		}
	}
}

func TestFormatCoachContextIncludesDietAndMonster(t *testing.T) {
	ctx := coachGroundedContext{
		Profile:   coachProfile{Nickname: "勇士", Height: 170, Weight: 70, SleepType: "标准作息"},
		Budget:    coachBudget{TargetCal: 1680, TodayCalIn: 800, RemainingCal: 880},
		Monster:   coachMonster{Name: "贪吃史莱姆", HP: 40, MaxHP: 100, Shield: 20},
		Meals:     []coachMealItem{{Name: "鸡蛋", TotalCal: 80, Meal: "breakfast", Grams: 50}},
		Exercises: []coachExercise{{Name: "深蹲", Duration: 10, Cal: 70}},
	}
	s := formatCoachContext(ctx, 1500)
	for _, needle := range []string{"鸡蛋", "贪吃史莱姆", "护盾=20", "深蹲", "安全下限=1500"} {
		if !strings.Contains(s, needle) {
			t.Fatalf("context missing %q in %s", needle, s)
		}
	}
}
