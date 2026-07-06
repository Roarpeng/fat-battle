export interface TauntCategory {
  taunt: string[]
  laugh: string[]
  challenge: string[]
  provocation: string[]
}

export const monsterTaunts: Record<string, TauntCategory> = {
  slime: {
    taunt: [
      '软软软软~ 打不到我！😜',
      '我是可爱的史莱姆~ 你舍得打我吗？🥺',
      '啵啵啵~ 你的攻击软绵绵的！💦',
      '我可是果冻做的！不怕痛！🍮',
      '嘿！你是不是没吃饭？力气好小！😆',
      '蹦蹦跳跳~ 抓不到我！🐸',
      '软软的身体，硬硬的意志！💪',
      '别白费力气了~ 我会恢复的！🔄',
      '今天的运动还不如我跳一下~ 🎶',
      '哈哈！你的攻击像挠痒痒！🤣',
    ],
    laugh: [
      '噗哈哈哈！太好笑了！🤣',
      '呵呵呵~ 小可怜！😏',
      '嘻嘻嘻~ 打不着打不着！🙈',
    ],
    challenge: [
      '来啊！打我啊！我不怕！😤',
      '就这点本事？再来啊！⚔️',
      '放马过来！我接招！🛡️',
    ],
    provocation: [
      '吃点好吃的吧~ 别这么辛苦！🍔',
      '休息一下~ 减肥慢慢来！😴',
      '躺平多舒服啊~ 干嘛要运动！🛌',
    ],
  },
  goblin: {
    taunt: [
      '叽叽喳喳！你这个大笨蛋！🦜',
      '我要把你的食物都抢光！🍖',
      '看看你！吃得比猪还多！🐷',
      '金币金币！都是我的！💰',
      '你的意志力比纸还薄！📄',
      '嘎嘎嘎！脂肪是我的好朋友！🤝',
      '想打败我？先去照照镜子！🪞',
      '我闻到了食物的味道！好香啊！👃',
      '你越吃我越开心！哈哈！😈',
      '可怜的人类！被脂肪打败了！😢',
    ],
    laugh: [
      '咯咯咯！笑死我了！🤣',
      '哈哈哈哈！太弱了！😆',
      '嘻嘻嘻！笨蛋笨蛋！😜',
    ],
    challenge: [
      '有本事来抢啊！我不怕你！😤',
      '金币在我手里！来拿啊！💰',
      '胆小鬼！不敢过来吗？🐔',
    ],
    provocation: [
      '炸鸡薯条配可乐！爽！🍟',
      '深夜放毒时间到！🍜',
      '别减肥了！一起吃！🍕',
    ],
  },
  ghost: {
    taunt: [
      '嘿嘿嘿~ 你看不见我！👻',
      '我是幽灵~ 伤害对我无效！💨',
      '飘呀飘呀~ 抓不到我！🎈',
      '你的意志力在消散~ 哈哈！💨',
      '我代表你的食欲~ 放弃吧！🍔',
      '虚无缥缈~ 你无法战胜我！🌫️',
      '饿了吗？我知道哪里有好吃的！🍩',
      '你的决心正在动摇！我感觉到了！😈',
      '放弃吧~ 减肥太难了！😢',
      '我会一直在你身边~ 永远！💫',
    ],
    laugh: [
      '嘿嘿嘿~ 有趣！😈',
      '咯咯咯~ 人类真脆弱！😏',
      '嘶嘶嘶~ 害怕了吗？🐍',
    ],
    challenge: [
      '想驱散我？除非你意志坚定！💎',
      '来吧！看看你的决心有多强！⚔️',
      '我的力量来自你的欲望！🔥',
    ],
    provocation: [
      '夜宵时间到~ 要不要来点？🌙',
      '睡吧睡吧~ 梦里啥都有！😴',
      '偶尔放纵一次没关系的~ 😉',
    ],
  },
  skeleton: {
    taunt: [
      '咔咔咔！我的骨头比你的意志硬！💀',
      '想击碎我？你还不够格！⚔️',
      '我是不死的！永远不会被击败！💀',
      '你的攻击对我无效！太弱了！🛡️',
      '看看你！比我还瘦吗？不可能！🦴',
      '我已经死了~ 但你还活着受罪！😈',
      '减肥？不如死了算了！💀',
      '你的脂肪比我的骨头还硬！🦴',
      '嘎嘎嘎！你打不碎我的！😆',
      '我是骷髅战士！永不退缩！⚔️',
    ],
    laugh: [
      '咔咔咔！笑死骷髅了！💀',
      '哈哈哈！骨头都在笑！🤣',
      '嘿嘿嘿！可怜的人类！😈',
    ],
    challenge: [
      '拿起武器！跟我决斗！⚔️',
      '你的意志力够锋利吗？🗡️',
      '让我看看你的实力！💀',
    ],
    provocation: [
      '坐下吧~ 站着多累！💺',
      '吃点东西补充能量！🍗',
      '你的骨头也会累的！🦴',
    ],
  },
  orc: {
    taunt: [
      '吼！你这个弱小的人类！👹',
      '我一拳就能打飞你！💥',
      '看看你的小身板！哈哈！😆',
      '我是兽人！力量无穷！💪',
      '你的运动简直是在给我挠痒！🦟',
      '脂肪是我的盔甲！你打不穿！🛡️',
      '放弃吧！你永远赢不了我！😈',
      '我要把你踩在脚下！👣',
      '你的意志力像纸一样脆弱！📄',
      '吼！让我来终结你的痛苦！⚔️',
    ],
    laugh: [
      '哈哈哈！弱小的人类！👹',
      '吼吼吼！太可笑了！😆',
      '嘿嘿嘿！不堪一击！😈',
    ],
    challenge: [
      '来吧！让我看看你的勇气！⚔️',
      '敢跟我正面交锋吗？💥',
      '我不会手下留情的！🛡️',
    ],
    provocation: [
      '大块吃肉！大碗喝酒！🍖',
      '你的减肥计划太可笑了！🤣',
      '跟我一起享受美食吧！🍗',
    ],
  },
  vampire: {
    taunt: [
      '呵呵~ 可怜的羔羊！🧛',
      '你的血液在沸腾~ 想放弃了吗？🩸',
      '夜晚是我的主场！🌙',
      '我可以闻到你的恐惧~ 哈哈！👃',
      '你逃不掉的！我会一直跟着你！🦇',
      '深夜的诱惑~ 你能抵挡吗？🍷',
      '你的意志力正在流失~ 像血一样！🩸',
      '跟我来吧~ 黑夜中有美食！🌃',
      '我是吸血鬼~ 永不满足！🧛',
      '你的努力只是我的开胃菜！🍽️',
    ],
    laugh: [
      '呵呵呵~ 有趣！🧛',
      '哈哈哈！可怜的人类！😈',
      '嘶嘶嘶~ 美味！🩸',
    ],
    challenge: [
      '在夜晚挑战我？你太愚蠢了！🌙',
      '想杀死吸血鬼？需要真正的勇气！⚔️',
      '来吧！让我吸干你的意志力！🧛',
    ],
    provocation: [
      '夜宵时间到~ 我请客！🌙',
      '熬夜多舒服~ 干嘛要早睡！💤',
      '红酒配甜点~ 人生巅峰！🍷',
    ],
  },
  dragon: {
    taunt: [
      '吼！你这个渺小的爬虫！🐉',
      '我的火焰会烧毁你的意志！🔥',
      '看看我的体型！你敢挑战我？😈',
      '我是巨龙！统治一切！👑',
      '你的攻击连我的鳞片都刮不破！🐉',
      '放弃吧！你永远是我的食物！🍽️',
      '我的力量来自千年的脂肪！🧠',
      '你以为你能击败一条龙？太天真了！😆',
      '我会把你烧成灰烬！🔥',
      '在我面前，你什么都不是！💀',
    ],
    laugh: [
      '吼哈哈哈！太可笑了！🐉',
      '哈哈哈！渺小的人类！🔥',
      '嘿嘿嘿！不自量力！😈',
    ],
    challenge: [
      '拿起你的武器！让我看看！⚔️',
      '你有勇气面对巨龙吗？🐉',
      '来吧！让我看看你的决心！🔥',
    ],
    provocation: [
      '美食盛宴！你确定不来？🍽️',
      '你的减肥计划在我面前不值一提！🤣',
      '跟着我！享受无尽的美食！🐉',
    ],
  },
  boss: {
    taunt: [
      '哈哈哈！终于见到你了！👑',
      '我是脂肪魔王！统治一切！😈',
      '你的努力只是徒劳！放弃吧！💪',
      '看看你的身材！你永远赢不了我！🪞',
      '我是你内心深处的欲望！永远存在！🔥',
      '减肥？那是不可能的！哈哈！😆',
      '你的意志力在我面前不堪一击！💀',
      '我会让你永远臣服于我！👑',
      '放弃吧！享受美食才是正道！🍔',
      '你以为你能战胜自己？太天真了！😈',
    ],
    laugh: [
      '哈哈哈！太可笑了！👑',
      '吼吼吼！可怜的人类！😈',
      '嘿嘿嘿！不自量力！💀',
    ],
    challenge: [
      '来吧！让我看看你的真正实力！⚔️',
      '你有勇气面对自己的欲望吗？🔥',
      '这是最后一战！你准备好了吗？👑',
    ],
    provocation: [
      '炸鸡汉堡薯条可乐！应有尽有！🍔',
      '放弃吧！跟我一起享受！😈',
      '你的减肥计划到此为止！👑',
    ],
  },
}

export function getRandomTaunt(monsterType: string): string {
  const typeTaunts = monsterTaunts[monsterType]
  if (!typeTaunts) {
    return monsterTaunts.slime.taunt[Math.floor(Math.random() * monsterTaunts.slime.taunt.length)]
  }

  const categories: Array<keyof TauntCategory> = ['taunt', 'laugh', 'challenge', 'provocation']
  const randomCategory = categories[Math.floor(Math.random() * categories.length)]
  const taunts = typeTaunts[randomCategory]

  return taunts[Math.floor(Math.random() * taunts.length)]
}

export function getTauntByTrigger(
  monsterType: string,
  trigger: 'high_hp' | 'low_hp' | 'after_damage' | 'after_heal'
): string {
  const typeTaunts = monsterTaunts[monsterType] || monsterTaunts.slime

  switch (trigger) {
    case 'high_hp':
      return typeTaunts.challenge[Math.floor(Math.random() * typeTaunts.challenge.length)]
    case 'low_hp':
      return typeTaunts.provocation[Math.floor(Math.random() * typeTaunts.provocation.length)]
    case 'after_damage':
      return typeTaunts.taunt[Math.floor(Math.random() * typeTaunts.taunt.length)]
    case 'after_heal':
      return typeTaunts.laugh[Math.floor(Math.random() * typeTaunts.laugh.length)]
    default:
      return typeTaunts.taunt[Math.floor(Math.random() * typeTaunts.taunt.length)]
  }
}