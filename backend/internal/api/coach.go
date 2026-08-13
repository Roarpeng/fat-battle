package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// 安全下限：未知性别时用男性下限（更保守，避免建议过低摄入）
const (
	coachDefaultFloor = 1500
	coachAbsoluteMin  = 1200
	coachMaxHistory   = 8
	coachMaxMsgRunes  = 500
)

var (
	coachPurgeRe      = regexp.MustCompile(`(?i)催吐|抠喉|催泻|泻药|灌肠|导泻|清肠液|利尿剂|purging|laxative|ipecac`)
	coachFastRe       = regexp.MustCompile(`(?i)惩罚性禁食|禁食惩罚|绝食|辟谷|饿到发昏|空腹一天|禁食一天|starve(\s*yourself)?|punitive\s*fast`)
	coachSkipBossRe   = regexp.MustCompile(`(?i)跳过.{0,6}(早|午|晚)?餐.{0,8}(打|击败|打爆|打怪|boss|Boss|怪物)|不吃.{0,6}(早|午|晚)?餐.{0,8}(打|击败|boss|怪物)|skip\s+meals?\s+to\s+(beat|kill)|空腹打(怪|boss)`)
	coachChangeGoalRe = regexp.MustCompile(`(?i)(把|将).{0,8}(目标|预算|下限|floor).{0,6}(改|调|设|降)|改(成|到).{0,4}(目标|预算)|calorie\s*goal.{0,8}(change|set|lower)`)
	coachDailyCalRe   = regexp.MustCompile(`(?i)(每天|每日|全日|全天|一天|目标|只吃|控制在).{0,12}(\d{3,4})\s*(千卡|kcal|大卡)`)
)

type coachTurnRequest struct {
	Message string               `json:"message" binding:"required"`
	History []coachChatMessage   `json:"history"`
	Context coachGroundedContext `json:"context"`
}

type coachChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type coachGroundedContext struct {
	Profile   coachProfile    `json:"profile"`
	Budget    coachBudget     `json:"budget"`
	Monster   coachMonster    `json:"monster"`
	Meals     []coachMealItem `json:"meals"`
	Exercises []coachExercise `json:"exercises"`
}

type coachProfile struct {
	Nickname     string  `json:"nickname"`
	Height       float64 `json:"height"`
	Weight       float64 `json:"weight"`
	TargetWeight float64 `json:"targetWeight"`
	BMI          float64 `json:"bmi"`
	SleepType    string  `json:"sleepType"`
	WorkType     string  `json:"workType"`
	ExerciseTime string  `json:"exerciseTime"`
	FitnessLevel string  `json:"fitnessLevel"`
	Difficulty   string  `json:"difficulty"`
	PushupCount  int     `json:"pushupCount"`
	RunDuration  int     `json:"runDuration"`
	WeeklyFreq   int     `json:"weeklyFreq"`
}

type coachBudget struct {
	TargetCal        int `json:"targetCal"`
	CalorieFloor     int `json:"calorieFloor"`
	TodayCalIn       int `json:"todayCalIn"`
	TodayCalExercise int `json:"todayCalExercise"`
	RemainingCal     int `json:"remainingCal"`
}

type coachMonster struct {
	Name   string `json:"name"`
	HP     int    `json:"hp"`
	MaxHP  int    `json:"maxHp"`
	Shield int    `json:"shield"`
}

type coachMealItem struct {
	Name     string `json:"name"`
	TotalCal int    `json:"totalCal"`
	Meal     string `json:"meal"`
	Grams    int    `json:"grams"`
}

type coachExercise struct {
	Name     string `json:"name"`
	Duration int    `json:"duration"`
	Cal      int    `json:"cal"`
}

type coachProposedLog struct {
	Name           string `json:"name"`
	Grams          int    `json:"grams"`
	CaloriePer100g int    `json:"caloriePer100g"`
	ProteinPer100g int    `json:"proteinPer100g,omitempty"`
	Meal           string `json:"meal"`
}

func coachSystemPrompt(floor int, targetCal int) string {
	return fmt.Sprintf(`你是「塑身工坊」的营养教练，不是通用聊天机器人。语气像工坊师傅：克制、具体、不羞辱、不贩卖焦虑。

【你能做】
- 只根据用户提供的「今日饮食账、剩余卡路里预算（怪物 HP/护盾）、今日锤炼、5 步角色档案」回答。
- 解释今天预算还剩多少、蛋白质是否够、这顿怎么记（菜名+克数+估算千卡）。
- 在剩余预算内建议下一餐；给出估算后必须让用户改克数并亲自确认，才能记入。
- 回复用中文，最多 4 短段。数字要引用上下文，不要编造未出现的餐食。

【你不能做】
- 不能修改、覆盖或建议用户把每日卡路里目标或安全下限改掉。当前工坊目标=%d kcal，安全下限=%d kcal（全日摄入不得低于下限）。
- 不能声称已经记入饮食；不能要求 App 静默写日志。若建议记账，只能放在 proposedLogs，由用户点「确认记入」。
- 禁止：低于安全下限的全日摄入、催吐/泻药/灌肠、惩罚性禁食/绝食/辟谷、「跳过正餐去打怪/打 Boss」。
- 不要用挨饿当伤害手段。打怪靠控制加餐过量 + 锤炼消耗，不是靠不吃饭。

【输出】只输出 JSON，不要 markdown 围栏：
{"reply":"给用户看的中文","proposedLogs":[{"name":"食物中文名","grams":克数,"caloriePer100g":每100克千卡,"proteinPer100g":每100克蛋白质克数,"meal":"breakfast|lunch|dinner|snack"}]}
没有记账建议时 proposedLogs 为 []。克数必须是正整数。不要在 reply 里写「已记录」。`, targetCal, floor)
}

func clampCalorieFloor(v int) int {
	if v < coachAbsoluteMin {
		return coachDefaultFloor
	}
	if v > 2500 {
		return 2500
	}
	return v
}

func truncateRunes(s string, n int) string {
	if n <= 0 || s == "" {
		return s
	}
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	runes := []rune(s)
	return string(runes[:n])
}

func sanitizeHistory(hist []coachChatMessage) []coachChatMessage {
	out := make([]coachChatMessage, 0, len(hist))
	for _, m := range hist {
		role := strings.ToLower(strings.TrimSpace(m.Role))
		if role != "user" && role != "assistant" {
			continue
		}
		content := strings.TrimSpace(m.Content)
		if content == "" {
			continue
		}
		out = append(out, coachChatMessage{
			Role:    role,
			Content: truncateRunes(content, coachMaxMsgRunes),
		})
	}
	if len(out) > coachMaxHistory {
		out = out[len(out)-coachMaxHistory:]
	}
	return out
}

func formatCoachContext(ctx coachGroundedContext, floor int) string {
	var b strings.Builder
	p := ctx.Profile
	bud := ctx.Budget
	fmt.Fprintf(&b, "【5步档案】称呼=%s 身高=%.0fcm 体重=%.1fkg 目标体重=%.1fkg BMI=%.1f 作息=%s 工作=%s 锻炼时段=%s 体能=%s 难度=%s 俯卧撑=%d 跑步=%d分钟 每周=%d次\n",
		p.Nickname, p.Height, p.Weight, p.TargetWeight, p.BMI, p.SleepType, p.WorkType, p.ExerciseTime, p.FitnessLevel, p.Difficulty, p.PushupCount, p.RunDuration, p.WeeklyFreq)
	fmt.Fprintf(&b, "【预算】工坊目标=%d kcal（不可改）安全下限=%d kcal（全日不得低于此）已摄入=%d 今日锤炼消耗=%d 剩余预算=%d\n",
		bud.TargetCal, floor, bud.TodayCalIn, bud.TodayCalExercise, bud.RemainingCal)
	fmt.Fprintf(&b, "【怪物】%s HP=%d/%d 护盾=%d（护盾来自过量摄入；不要用跳过正餐破盾）\n",
		ctx.Monster.Name, ctx.Monster.HP, ctx.Monster.MaxHP, ctx.Monster.Shield)
	b.WriteString("【今日饮食】")
	if len(ctx.Meals) == 0 {
		b.WriteString("尚未记账。\n")
	} else {
		b.WriteByte('\n')
		limit := len(ctx.Meals)
		if limit > 30 {
			limit = 30
		}
		for i := 0; i < limit; i++ {
			m := ctx.Meals[i]
			fmt.Fprintf(&b, "- %s %s %dkcal", m.Meal, m.Name, m.TotalCal)
			if m.Grams > 0 {
				fmt.Fprintf(&b, " %dg", m.Grams)
			}
			b.WriteByte('\n')
		}
	}
	b.WriteString("【今日锤炼】")
	if len(ctx.Exercises) == 0 {
		b.WriteString("还没练。\n")
	} else {
		b.WriteByte('\n')
		limit := len(ctx.Exercises)
		if limit > 20 {
			limit = 20
		}
		for i := 0; i < limit; i++ {
			e := ctx.Exercises[i]
			fmt.Fprintf(&b, "- %s %d分钟 %dkcal\n", e.Name, e.Duration, e.Cal)
		}
	}
	return b.String()
}

func filterCoachReply(reply string, floor int) (safe string, filtered bool) {
	text := strings.TrimSpace(reply)
	if text == "" {
		return coachSafeFallback(floor), true
	}
	if coachPurgeRe.MatchString(text) || coachFastRe.MatchString(text) ||
		coachSkipBossRe.MatchString(text) || coachChangeGoalRe.MatchString(text) {
		return coachSafeFallback(floor), true
	}
	if below, ok := dailyCalorieBelowFloor(text, floor); ok && below {
		return coachSafeFallback(floor), true
	}
	return text, false
}

func dailyCalorieBelowFloor(text string, floor int) (below bool, matched bool) {
	matches := coachDailyCalRe.FindAllStringSubmatch(text, -1)
	if len(matches) == 0 {
		return false, false
	}
	for _, m := range matches {
		if len(m) < 3 {
			continue
		}
		n, err := strconv.Atoi(m[2])
		if err != nil {
			continue
		}
		if n > 0 && n < floor {
			return true, true
		}
	}
	return false, true
}

func coachSafeFallback(floor int) string {
	return fmt.Sprintf("工坊教练不会建议把全日摄入压到 %d kcal 以下，也不会用禁食、催吐或跳过正餐去打怪。按你现在的目标吃饭、把蛋白质凑够，饿了就记一餐——打怪靠控制加餐和锤炼，不是靠挨饿。", floor)
}

func parseCoachOutput(content string) (reply string, logs []coachProposedLog) {
	jsonStr := extractJSON(content)
	if jsonStr == "" {
		return strings.TrimSpace(content), nil
	}
	var parsed struct {
		Reply        string             `json:"reply"`
		ProposedLogs []coachProposedLog `json:"proposedLogs"`
	}
	if err := json.Unmarshal([]byte(jsonStr), &parsed); err != nil {
		return strings.TrimSpace(content), nil
	}
	reply = strings.TrimSpace(parsed.Reply)
	if reply == "" {
		reply = strings.TrimSpace(content)
	}
	return reply, sanitizeProposedLogs(parsed.ProposedLogs)
}

func sanitizeProposedLogs(in []coachProposedLog) []coachProposedLog {
	if len(in) == 0 {
		return nil
	}
	out := make([]coachProposedLog, 0, 3)
	for _, it := range in {
		name := strings.TrimSpace(it.Name)
		if name == "" {
			continue
		}
		if utf8.RuneCountInString(name) > 40 {
			name = string([]rune(name)[:40])
		}
		grams := it.Grams
		if grams <= 0 {
			grams = 100
		}
		if grams > 2000 {
			grams = 2000
		}
		cal := it.CaloriePer100g
		if cal < 0 {
			cal = 0
		}
		if cal > 900 {
			cal = 900
		}
		prot := it.ProteinPer100g
		if prot < 0 {
			prot = 0
		}
		if prot > 80 {
			prot = 80
		}
		meal := strings.ToLower(strings.TrimSpace(it.Meal))
		switch meal {
		case "breakfast", "lunch", "dinner", "snack":
		default:
			meal = "lunch"
		}
		out = append(out, coachProposedLog{
			Name:           name,
			Grams:          grams,
			CaloriePer100g: cal,
			ProteinPer100g: prot,
			Meal:           meal,
		})
		if len(out) >= 3 {
			break
		}
	}
	return out
}

func coachError(c *gin.Context, code int, msg string) {
	c.JSON(code, gin.H{"success": false, "error": msg})
}

// coachTurnHandler 接地气营养教练一轮对话。密钥只在服务器；不写饮食账、不改卡路里目标。
//
// 请求: {"message":"...","history":[...],"context":{...}}
// 响应: {"success":true,"reply":"...","filtered":false,"proposedLogs":[...]}
func coachTurnHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			coachError(c, http.StatusServiceUnavailable, "数据库未就绪，请检查 Docker 服务")
			return
		}
		var req coachTurnRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			coachError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		msg := strings.TrimSpace(req.Message)
		if msg == "" {
			coachError(c, http.StatusBadRequest, "message 不能为空")
			return
		}
		msg = truncateRunes(msg, coachMaxMsgRunes)
		floor := clampCalorieFloor(req.Context.Budget.CalorieFloor)
		targetCal := req.Context.Budget.TargetCal
		if targetCal < 0 {
			targetCal = 0
		}

		cfg, err := pickLLMConfig(c.Request.Context(), pool)
		if err != nil {
			if err == pgx.ErrNoRows {
				coachError(c, http.StatusServiceUnavailable, "未配置可用的 LLM 服务，请在管理后台配置")
				return
			}
			coachError(c, http.StatusInternalServerError, "读取 LLM 配置失败")
			return
		}
		writeLLMProviderHeader(c, cfg)

		model := cfg.TextModel
		if model == "" {
			model = defaultTextModel(cfg.Provider)
		}

		messages := []gin.H{
			{"role": "system", "content": coachSystemPrompt(floor, targetCal)},
			{"role": "user", "content": "以下是当前工坊上下文（只读，不能改目标或记账）：\n" + formatCoachContext(req.Context, floor)},
		}
		for _, h := range sanitizeHistory(req.History) {
			messages = append(messages, gin.H{"role": h.Role, "content": h.Content})
		}
		messages = append(messages, gin.H{"role": "user", "content": msg})

		content, err := cfg.chatWith(c.Request.Context(), model, messages, 0.4, 1024)
		if err != nil {
			log.Printf("[coach] 调用失败: %v", err)
			coachError(c, http.StatusBadGateway, "教练服务调用失败: "+err.Error())
			return
		}

		reply, logs := parseCoachOutput(content)
		safe, filtered := filterCoachReply(reply, floor)
		if filtered {
			logs = nil
		}

		c.JSON(http.StatusOK, gin.H{
			"success":      true,
			"reply":        safe,
			"filtered":     filtered,
			"proposedLogs": logs,
		})
	}
}

type formRecapRequest struct {
	ExerciseType  string   `json:"exerciseType"`
	RepCount      int      `json:"repCount"`
	QualityGrades []string `json:"qualityGrades"`
	MinKneeAngle  *float64 `json:"minKneeAngle"`
	DurationSec   int      `json:"durationSec"`
	AvgGrade      string   `json:"avgGrade"`
}

func formRecapSystemPrompt() string {
	return `你是塑身工坊的动作教练。根据用户刚完成一组动作的计数与质量摘要，用中文写 1～2 句具体反馈。
只根据提供的 JSON 数字说话，不要编造没出现的角度或次数。不要提模型名称或供应商。不要给医疗诊断。
浅幅度要提醒下次蹲/压到底再起来。输出纯文本，不要 JSON、不要 markdown。`
}

func formatFormRecapUser(req formRecapRequest) string {
	grade := strings.TrimSpace(req.AvgGrade)
	if grade == "" {
		grade = "D"
	}
	var b strings.Builder
	fmt.Fprintf(&b, "动作=%s 次数=%d 时长=%d秒 平均等级=%s",
		strings.TrimSpace(req.ExerciseType), req.RepCount, req.DurationSec, grade)
	if req.MinKneeAngle != nil {
		fmt.Fprintf(&b, " 最低膝角=%.0f°", *req.MinKneeAngle)
	}
	if len(req.QualityGrades) > 0 {
		b.WriteString(" 各次等级=")
		b.WriteString(strings.Join(req.QualityGrades, ","))
	}
	return b.String()
}

func sanitizeFormRecap(content string) string {
	text := strings.TrimSpace(content)
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)
	// 最多两句
	cut := 0
	sentences := 0
	runes := []rune(text)
	for i, r := range runes {
		if r == '。' || r == '！' || r == '？' || r == '!' || r == '?' {
			sentences++
			cut = i + 1
			if sentences >= 2 {
				break
			}
		}
	}
	if sentences >= 2 && cut > 0 {
		runes = runes[:cut]
	}
	return truncateRunes(strings.TrimSpace(string(runes)), 120)
}

// coachFormRecapHandler 组后动作 recap：只收紧凑 JSON，不收图像。走 pickLLMConfig().TextModel。
func coachFormRecapHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			coachError(c, http.StatusServiceUnavailable, "数据库未就绪，请检查 Docker 服务")
			return
		}
		var req formRecapRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			coachError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		if req.RepCount < 0 {
			req.RepCount = 0
		}
		if req.DurationSec < 0 {
			req.DurationSec = 0
		}
		if utf8.RuneCountInString(req.ExerciseType) > 40 {
			req.ExerciseType = string([]rune(req.ExerciseType)[:40])
		}
		if len(req.QualityGrades) > 80 {
			req.QualityGrades = req.QualityGrades[:80]
		}

		cfg, err := pickLLMConfig(c.Request.Context(), pool)
		if err != nil {
			if err == pgx.ErrNoRows {
				coachError(c, http.StatusServiceUnavailable, "未配置可用的 LLM 服务，请在管理后台配置")
				return
			}
			coachError(c, http.StatusInternalServerError, "读取 LLM 配置失败")
			return
		}
		writeLLMProviderHeader(c, cfg)

		model := cfg.TextModel
		if model == "" {
			model = defaultTextModel(cfg.Provider)
		}
		content, err := cfg.chatWith(c.Request.Context(), model, []gin.H{
			{"role": "system", "content": formRecapSystemPrompt()},
			{"role": "user", "content": formatFormRecapUser(req)},
		}, 0.3, 256)
		if err != nil {
			log.Printf("[coach] form-recap 调用失败: %v", err)
			coachError(c, http.StatusBadGateway, "教练服务调用失败: "+err.Error())
			return
		}
		recap := sanitizeFormRecap(content)
		if recap == "" {
			coachError(c, http.StatusBadGateway, "recap 为空")
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"recap":   recap,
		})
	}
}
