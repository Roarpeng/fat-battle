package domain

import (
	"encoding/json"
	"testing"
)

func TestParseGameStateExtractsProfileAndSculpt(t *testing.T) {
	raw := json.RawMessage(`{
		"user": {
			"nickname": "勇士",
			"avatar": "🧑",
			"age": 28,
			"gender": "female",
			"height": 165,
			"weight": 58.5,
			"targetWeight": 54,
			"bmi": 0,
			"sleepType": 1,
			"workType": 0,
			"exerciseTime": 2,
			"characterStyle": 0,
			"fitnessLevel": 1,
			"pushupCount": 8,
			"runDuration": 12,
			"weeklyFreq": 3,
			"difficulty": 1,
			"sculptLine": "venus",
			"kneeIssue": true,
			"waistIssue": false
		},
		"targetCal": 1600,
		"streak": 5,
		"sculptStage": 3,
		"sculptProgress": 0.75,
		"sculptSettledCount": 12,
		"sculptLastSettledDate": "2026-08-13",
		"sculptMaintenance": false,
		"visualTheme": "forge",
		"lastDate": "2026-08-13",
		"meals": {
			"0": [{"name":"燕麦","totalCal":320,"grams":80}],
			"1": [{"name":"鸡胸","totalCal":250}]
		},
		"exercises": [
			{"id":"e1","date":"2026-08-13","name":"深蹲","cal":120,"damage":30,"mode":"camera"}
		],
		"weightRecords": [{"date":"2026-08-13","weight":58.5}],
		"waistRecords": [{"date":"2026-08-13","waistCm":72}]
	}`)
	ex := ParseGameState(raw)
	if ex.Profile.Nickname == nil || *ex.Profile.Nickname != "勇士" {
		t.Fatalf("nickname: %+v", ex.Profile.Nickname)
	}
	if ex.Profile.Gender == nil || *ex.Profile.Gender != "female" {
		t.Fatalf("gender: %+v", ex.Profile.Gender)
	}
	if ex.Profile.SleepType == nil || *ex.Profile.SleepType != "normal" {
		t.Fatalf("sleep: %+v", ex.Profile.SleepType)
	}
	if ex.Profile.CalorieFloor == nil || *ex.Profile.CalorieFloor != FemaleCalorieFloor {
		t.Fatalf("female floor: %+v", ex.Profile.CalorieFloor)
	}
	if ex.Profile.BMI == nil || *ex.Profile.BMI < 20 || *ex.Profile.BMI > 22 {
		t.Fatalf("computed bmi: %+v", ex.Profile.BMI)
	}
	if ex.Sculpt.Stage != 3 || ex.Sculpt.Line != "venus" || ex.Sculpt.Maintenance != "none" {
		t.Fatalf("sculpt: %+v", ex.Sculpt)
	}
	if len(ex.Meals) != 2 {
		t.Fatalf("meals %d", len(ex.Meals))
	}
	if len(ex.Sessions) != 1 || ex.Sessions[0].Mode != "camera" {
		t.Fatalf("sessions: %+v", ex.Sessions)
	}
	if len(ex.Metrics) != 1 || ex.Metrics[0].WeightKG == nil {
		t.Fatalf("metrics: %+v", ex.Metrics)
	}
}

func TestParseGameStateToleratesMissingKeys(t *testing.T) {
	ex := ParseGameState(json.RawMessage(`{"day":1}`))
	if ex.Sculpt.Line != "venus" {
		t.Fatalf("default line %s", ex.Sculpt.Line)
	}
	if ex.Profile.CalorieFloor == nil || *ex.Profile.CalorieFloor != DefaultCalorieFloor {
		t.Fatalf("default floor")
	}
	if len(ex.Meals) != 0 || len(ex.Sessions) != 0 {
		t.Fatal("empty lists expected")
	}
}

func TestParseGameStateInvalidJSON(t *testing.T) {
	ex := ParseGameState(json.RawMessage(`not-json`))
	if ex.Raw == nil {
		t.Fatal("raw map should be empty not nil-panic")
	}
}

func TestPatchGameStateJSON(t *testing.T) {
	raw := json.RawMessage(`{"user":{"weight":70},"targetCal":1800,"streak":1,"sculptStage":1,"visualTheme":"forge"}`)
	out, err := PatchGameStateJSON(raw, map[string]any{
		"weight": 68.2, "targetCal": 1700, "streak": 4, "sculptStage": 5, "sculptLine": "david", "visualTheme": "ink",
	})
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(out, &m); err != nil {
		t.Fatal(err)
	}
	user := m["user"].(map[string]any)
	if user["weight"].(float64) != 68.2 {
		t.Fatalf("weight %v", user["weight"])
	}
	if user["sculptLine"] != "david" {
		t.Fatalf("line %v", user["sculptLine"])
	}
	if m["targetCal"].(float64) != 1700 || m["sculptStage"].(float64) != 5 {
		t.Fatalf("top-level %v", m)
	}
	if m["visualTheme"] != "ink" {
		t.Fatalf("theme %v", m["visualTheme"])
	}
}

func TestNormalizeHelpers(t *testing.T) {
	if NormalizeFeel("tooEasy") != "too_easy" {
		t.Fatal(NormalizeFeel("tooEasy"))
	}
	if NormalizeMealSlot("0") != "breakfast" || NormalizeMealSlot("snack") != "snack" {
		t.Fatal("meal slot")
	}
	if CalorieFloorForGender("female") != 1200 || CalorieFloorForGender("male") != 1500 {
		t.Fatal("floor")
	}
}

func TestMaintenanceFromStage(t *testing.T) {
	raw := json.RawMessage(`{"sculptStage":7,"sculptMaintenance":true}`)
	ex := ParseGameState(raw)
	if ex.Sculpt.Maintenance != "rebound" {
		t.Fatalf("got %s", ex.Sculpt.Maintenance)
	}
}
