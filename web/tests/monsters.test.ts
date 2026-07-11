import { describe, it, expect } from 'vitest'
import {
  COUNTER_MAP,
  COUNTER_MULTIPLIER,
  WEAK_MULTIPLIER,
  getExerciseMultiplier,
  getMonsterDefByLevel,
} from '../src/data/monsters'

describe('COUNTER_MAP', () => {
  it('forms a triangle cycle: cardio -> strength -> core -> cardio', () => {
    expect(COUNTER_MAP.cardio).toBe('strength')
    expect(COUNTER_MAP.strength).toBe('core')
    expect(COUNTER_MAP.core).toBe('cardio')
  })
})

describe('multiplier constants', () => {
  it('has correct counter multiplier', () => {
    expect(COUNTER_MULTIPLIER).toBe(1.5)
  })

  it('has correct weak multiplier', () => {
    expect(WEAK_MULTIPLIER).toBe(0.7)
  })
})

describe('getExerciseMultiplier', () => {
  it('returns counter when exercise category matches monster weakness', () => {
    // slime: weakness='cardio', affinity='core'
    // running is cardio -> matches weakness
    const result = getExerciseMultiplier('running', 'cardio', 'core')
    expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
    expect(result.isCounter).toBe(true)
  })

  it('returns weak multiplier when exercise category matches monster affinity', () => {
    // slime: weakness='cardio', affinity='core'
    // plank is core -> matches affinity
    const result = getExerciseMultiplier('plank', 'cardio', 'core')
    expect(result.multiplier).toBe(WEAK_MULTIPLIER)
    expect(result.isResisted).toBe(true)
  })

  it('returns weak multiplier for strength vs ghost', () => {
    // ghost: weakness='core', affinity='strength'
    // squat (strength) -> matches affinity
    const result = getExerciseMultiplier('squat', 'core', 'strength')
    expect(result.multiplier).toBe(WEAK_MULTIPLIER)
    expect(result.isResisted).toBe(true)
  })

  it('returns counter via COUNTER_MAP for strength vs core affinity', () => {
    // slime: weakness='cardio', affinity='core'
    // squat (strength): COUNTER_MAP['strength']='core' === monsterAffinity 'core' -> counter
    const result = getExerciseMultiplier('squat', 'cardio', 'core')
    expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
    expect(result.isCounter).toBe(true)
  })

  it('returns counter via COUNTER_MAP for core vs cardio affinity', () => {
    // goblin: weakness='strength', affinity='cardio'
    // plank (core): COUNTER_MAP['core']='cardio' === monsterAffinity 'cardio' -> counter
    const result = getExerciseMultiplier('plank', 'strength', 'cardio')
    expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
    expect(result.isCounter).toBe(true)
  })

  it('returns counter via weakness match for strength vs goblin', () => {
    // goblin: weakness='strength', affinity='cardio'
    // squat (strength) -> matches weakness
    const result = getExerciseMultiplier('squat', 'strength', 'cardio')
    expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
    expect(result.isCounter).toBe(true)
  })

  it('returns weak multiplier for cardio vs goblin', () => {
    // goblin: weakness='strength', affinity='cardio'
    // running (cardio) -> matches affinity
    const result = getExerciseMultiplier('running', 'strength', 'cardio')
    expect(result.multiplier).toBe(WEAK_MULTIPLIER)
    expect(result.isResisted).toBe(true)
  })

  it('returns default for unknown exercise', () => {
    const result = getExerciseMultiplier('unknown', 'cardio', 'core')
    expect(result.multiplier).toBe(1.0)
    expect(result.isCounter).toBe(false)
    expect(result.isResisted).toBe(false)
  })
})

describe('getMonsterDefByLevel', () => {
  it('returns minion for levels 1-4', () => {
    expect(getMonsterDefByLevel(1).tier).toBe('minion')
    expect(getMonsterDefByLevel(2).tier).toBe('minion')
    expect(getMonsterDefByLevel(3).tier).toBe('minion')
    expect(getMonsterDefByLevel(4).tier).toBe('minion')
  })

  it('returns elite for level 5', () => {
    expect(getMonsterDefByLevel(5).tier).toBe('elite')
  })

  it('returns minion for levels 6-9', () => {
    expect(getMonsterDefByLevel(6).tier).toBe('minion')
    expect(getMonsterDefByLevel(9).tier).toBe('minion')
  })

  it('returns boss for level 10', () => {
    expect(getMonsterDefByLevel(10).tier).toBe('boss')
  })

  it('returns elite for level 15', () => {
    expect(getMonsterDefByLevel(15).tier).toBe('elite')
  })

  it('returns boss for level 20', () => {
    expect(getMonsterDefByLevel(20).tier).toBe('boss')
  })

  it('returns boss for level 50 (divisible by 10)', () => {
    expect(getMonsterDefByLevel(50).tier).toBe('boss')
  })

  it('returns finalboss for level >= 50 not divisible by 5', () => {
    expect(getMonsterDefByLevel(51).tier).toBe('finalboss')
    expect(getMonsterDefByLevel(52).tier).toBe('finalboss')
  })
})
