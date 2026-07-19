export interface DamageNumberProps {
  id: string;
  value: number;
  type: 'damage' | 'heal' | 'critical';
  x?: number;
  y?: number;
}

export interface FloatingTextProps {
  id: string;
  text: string;
  type: 'encouragement' | 'taunt' | 'system';
}

export interface AttackEffectProps {
  id: string;
  type: 'missile' | 'knife' | 'punch' | 'fireball' | 'lightning' | 'grease' | 'bomb';
  damage: number;
  isOvereat?: boolean;
}

export interface MonsterAnimationProps {
  emoji: string;
  isShaking?: boolean;
  isHit?: boolean;
  isDead?: boolean;
  hpPercentage: number;
}

export interface EnergyShieldProps {
  overeatCalories: number;
  maxCalories?: number;
}

export interface VictoryEffectProps {
  onComplete?: () => void;
}

export interface StoryBubbleProps {
  text: string;
  visible: boolean;
  type: 'encounter' | 'phaseChange' | 'enrage' | 'defeat';
  onClose: () => void;
}
