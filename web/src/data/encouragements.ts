export interface Encouragement {
  id: string;
  message: string;
  type: 'food_good' | 'food_warning' | 'exercise_start' | 'exercise_progress' | 'exercise_complete' | 'battle_victory' | 'battle_progress' | 'daily_checkin' | 'streak' | 'weight_loss';
  emoji?: string;
}

export const encouragementMessages: Record<string, string[]> = {
  food_good: [
    '太棒了！健康的选择！💪',
    '这个食物很适合减肥哦~ 🥗',
    '聪明的选择！脂肪怪要哭了~ 😭',
    '营养均衡，继续保持！✨',
    '这个食物很友好，怪物很受伤！⚔️',
    '完美！你的意志力在燃烧！🔥',
    '健康饮食，击败脂肪！🥦',
    '好样的！离胜利又近了一步！🚀',
    '这个选择让怪物瑟瑟发抖！😱',
    '吃得健康，练得开心！😊',
  ],
  food_warning: [
    '小心哦~ 这个有点高热量！⚠️',
    '偶尔吃没关系，但别太频繁哦~ 😅',
    '脂肪怪在偷偷笑呢！😈',
    '下次可以试试更健康的选择~ 🥗',
    '这个会让怪物变强的！💪',
    '注意控制分量哦~ 📏',
    '怪物说：再来点！🍔',
    '小心护盾增加！🛡️',
    '这顿吃完要多运动哦~ 🏃',
    '偶尔放纵没问题，明天继续加油！💪',
  ],
  exercise_start: [
    '准备好了吗？让怪物尝尝你的厉害！⚔️',
    '开始燃烧卡路里吧！🔥',
    '怪物在等你呢！冲啊！🚀',
    '动起来！脂肪怪最怕这个！💪',
    '今天也要全力以赴哦！✨',
    '汗水是胜利的勋章！💦',
    '准备好给怪物致命一击了吗？😤',
    '你的努力会有回报的！🏆',
    '让运动成为你的武器！🗡️',
    '燃烧吧！小宇宙！🔥',
  ],
  exercise_progress: [
    '太棒了！已经完成一半了！💪',
    '怪物在惨叫！继续！😈',
    '你的汗水在变成伤害！⚔️',
    '再来一点！怪物快不行了！🩸',
    '坚持就是胜利！你可以的！✨',
    '每一滴汗水都是对怪物的打击！💦',
    '加油！伤害在累积！🔥',
    '怪物的血量在下降！继续！📉',
    '你比想象中更强大！💪',
    '胜利就在眼前！不要停！🏁',
  ],
  exercise_complete: [
    '完美！造成了巨额伤害！⚔️',
    '怪物被你打懵了！😱',
    '太厉害了！这就是你的实力！💪',
    '燃烧卡路里，击败脂肪怪！🔥',
    '胜利在望！继续保持！🏆',
    '你的努力让怪物瑟瑟发抖！😈',
    '伤害爆表！怪物要哭了！😭',
    '太帅了！这波操作满分！💯',
    '汗水不会辜负你！✨',
    '怪物血量告急！再来一波！🩸',
  ],
  battle_victory: [
    '🎉 恭喜！击败了怪物！',
    '🏆 胜利！你是真正的减肥战士！',
    '⚔️ 完美击杀！怪物被你征服了！',
    '🌟 太棒了！今日任务完成！',
    '💰 获得奖励！继续前进！',
    '👑 你是王者！怪物俯首称臣！',
    '🔥 燃爆了！这就是你的实力！',
    '💪 胜利属于坚持的你！',
    '✨ 光芒四射！减肥路上的里程碑！',
    '🎊 庆祝吧！你做到了！',
  ],
  battle_progress: [
    '怪物血量下降了！继续！📉',
    '怪物在挣扎！给它最后一击！⚔️',
    '伤害生效！怪物很痛苦！😫',
    '怪物的护盾被打破了！🛡️',
    '怪物要不行了！再加把劲！💪',
    '完美！怪物在流血！🩸',
    '继续攻击！胜利就在眼前！🏁',
    '怪物的表情变了！它害怕了！😱',
    '你的攻击越来越犀利了！⚔️',
    '怪物快撑不住了！冲啊！🚀',
  ],
  daily_checkin: [
    '📅 签到成功！新的一天开始了！',
    '🌅 美好的一天从打卡开始！',
    '✨ 坚持就是胜利！继续加油！',
    '💪 今天也要全力以赴哦！',
    '🌟 每一天都是新的挑战！',
    '🔥 燃烧卡路里的一天开始了！',
    '🥊 准备好迎接今天的怪物了吗？',
    '💯 打卡成功！你是最棒的！',
    '🚀 新的一天，新的目标！',
    '🌈 今天也要元气满满哦！',
  ],
  streak: [
    '🔥 连续3天！你已经养成习惯了！',
    '⭐ 连续7天！真是太棒了！',
    '🌟 连续14天！毅力惊人！',
    '👑 连续30天！你是传奇！',
    '💪 连续打卡！习惯的力量！',
    '🔥 火热的连续记录！继续保持！',
    '🏆 连续打卡成就达成！',
    '✨ 坚持就是胜利的秘诀！',
    '⚡ 连续记录让你更强！',
    '🎯 连续打卡，目标更近了！',
  ],
  weight_loss: [
    '🎉 恭喜！体重下降了！',
    '📉 脂肪在燃烧！继续！',
    '🏆 又瘦了！太棒了！',
    '✨ 你的努力有回报了！',
    '💪 离目标越来越近！',
    '🌟 体重下降，信心上升！',
    '🔥 脂肪正在逃离！',
    '🎯 目标达成又近了一步！',
    '🌈 身材越来越好！',
    '👑 你是减肥冠军！',
  ],
};

export function getRandomEncouragement(type: keyof typeof encouragementMessages): string {
  const messages = encouragementMessages[type];
  return messages[Math.floor(Math.random() * messages.length)];
}

export function getExerciseProgressMessage(current: number, total: number): string {
  const progress = current / total;
  if (progress <= 0.25) {
    return encouragementMessages.exercise_progress[0];
  } else if (progress <= 0.5) {
    return encouragementMessages.exercise_progress[1];
  } else if (progress <= 0.75) {
    return encouragementMessages.exercise_progress[2];
  } else {
    return encouragementMessages.exercise_progress[3];
  }
}