import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import {
  withRetry,
  withTimeout,
  computeDelay,
  RetryTimeoutError,
  NetworkError,
  isNetworkError,
  isNonRetryableError,
  defaultShouldRetry,
} from '../retry'

describe('withRetry', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('成功执行时不重试', async () => {
    const fn = vi.fn().mockResolvedValue('ok')
    const onRetry = vi.fn()

    const result = await withRetry(fn, { retries: 3, onRetry })

    expect(result).toBe('ok')
    expect(fn).toHaveBeenCalledTimes(1)
    expect(onRetry).not.toHaveBeenCalled()
  })

  it('重试后成功', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new Error('fail 1'))
      .mockRejectedValueOnce(new Error('fail 2'))
      .mockResolvedValueOnce('ok')
    const onRetry = vi.fn()

    const promise = withRetry(fn, { retries: 3, delay: 100, onRetry })

    // 第一次失败后等待 100ms (exponential: 100 * 2^0)
    await vi.advanceTimersByTimeAsync(100)
    // 第二次失败后等待 200ms (exponential: 100 * 2^1)
    await vi.advanceTimersByTimeAsync(200)

    const result = await promise
    expect(result).toBe('ok')
    expect(fn).toHaveBeenCalledTimes(3)
    expect(onRetry).toHaveBeenCalledTimes(2)
    expect(onRetry).toHaveBeenNthCalledWith(1, expect.any(Error), 1)
    expect(onRetry).toHaveBeenNthCalledWith(2, expect.any(Error), 2)
  })

  it('重试次数耗尽时抛出最后一个错误', async () => {
    const error = new Error('always fail')
    const fn = vi.fn().mockImplementation(async () => { throw error })
    const onRetry = vi.fn()

    const promise = withRetry(fn, { retries: 2, delay: 50, onRetry })
    promise.catch(() => {})

    await vi.advanceTimersByTimeAsync(50)
    await vi.advanceTimersByTimeAsync(100)

    await expect(promise).rejects.toThrow('always fail')
    // 初始执行 + 2 次重试 = 3 次
    expect(fn).toHaveBeenCalledTimes(3)
    expect(onRetry).toHaveBeenCalledTimes(2)
  })

  it('指数退避延迟按 factor^(attempt-1) 递增', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new Error('fail 1'))
      .mockRejectedValueOnce(new Error('fail 2'))
      .mockResolvedValueOnce('ok')
    const onRetry = vi.fn()

    const promise = withRetry(fn, {
      retries: 3,
      delay: 1000,
      backoff: 'exponential',
      factor: 2,
      onRetry,
    })

    // 第一次失败 → 等待 1000ms (1000 * 2^0)
    expect(fn).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(999)
    expect(fn).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(1)
    // 此时第二次已执行
    expect(fn).toHaveBeenCalledTimes(2)

    // 第二次失败 → 等待 2000ms (1000 * 2^1)
    await vi.advanceTimersByTimeAsync(1999)
    expect(fn).toHaveBeenCalledTimes(2)
    await vi.advanceTimersByTimeAsync(1)
    expect(fn).toHaveBeenCalledTimes(3)

    const result = await promise
    expect(result).toBe('ok')

    // 验证退避时长通过 computeDelay 计算一致
    expect(computeDelay(1, 1000, 'exponential', 2)).toBe(1000)
    expect(computeDelay(2, 1000, 'exponential', 2)).toBe(2000)
    expect(computeDelay(3, 1000, 'exponential', 2)).toBe(4000)
  })

  it('线性退避延迟按 delay * attempt * factor 递增', () => {
    expect(computeDelay(1, 1000, 'linear', 2)).toBe(2000)
    expect(computeDelay(2, 1000, 'linear', 2)).toBe(4000)
    expect(computeDelay(3, 1000, 'linear', 2)).toBe(6000)
  })

  it('shouldRetry 返回 false 时立即抛出不重试', async () => {
    const argError = new Error('invalid argument')
    const fn = vi.fn().mockRejectedValue(argError)
    const onRetry = vi.fn()

    await expect(
      withRetry(fn, {
        retries: 3,
        delay: 100,
        shouldRetry: (err) => isNetworkError(err),
        onRetry,
      })
    ).rejects.toThrow('invalid argument')

    expect(fn).toHaveBeenCalledTimes(1)
    expect(onRetry).not.toHaveBeenCalled()
  })

  it('shouldRetry 为网络错误时返回 true 才重试', async () => {
    const networkError = new NetworkError('network down')
    const fn = vi.fn()
      .mockRejectedValueOnce(networkError)
      .mockResolvedValueOnce('ok')

    const promise = withRetry(fn, {
      retries: 3,
      delay: 100,
      shouldRetry: (err) => isNetworkError(err),
    })

    await vi.advanceTimersByTimeAsync(100)
    const result = await promise

    expect(result).toBe('ok')
    expect(fn).toHaveBeenCalledTimes(2)
  })

  it('使用默认 shouldRetry 时网络错误会重试', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new NetworkError('网络错误'))
      .mockResolvedValueOnce('ok')

    const promise = withRetry(fn, { retries: 3, delay: 100 })
    await vi.advanceTimersByTimeAsync(100)
    const result = await promise

    expect(result).toBe('ok')
    expect(fn).toHaveBeenCalledTimes(2)
  })

  it('使用默认 shouldRetry 时参数错误不重试', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('参数错误'))

    const promise = withRetry(fn, { retries: 3, delay: 100 })
    await expect(promise).rejects.toThrow('参数错误')
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('抛出非 Error 对象时会被包装为 Error', async () => {
    const fn = vi.fn().mockImplementation(async () => {
      throw 'string error'
    })

    const promise = withRetry(fn, { retries: 1, delay: 50 })
    promise.catch(() => {})
    await vi.advanceTimersByTimeAsync(50)
    await expect(promise).rejects.toThrow('string error')
  })

  it('retries=0 表示不重试', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('fail'))
    const promise = withRetry(fn, { retries: 0, delay: 100 })

    await expect(promise).rejects.toThrow('fail')
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('使用 onRetry 回调收到错误与尝试次数', async () => {
    const errors: Error[] = []
    const attempts: number[] = []
    const fn = vi.fn()
      .mockRejectedValueOnce(new Error('e1'))
      .mockResolvedValueOnce('ok')

    const promise = withRetry(fn, {
      retries: 2,
      delay: 100,
      onRetry: (err, attempt) => {
        errors.push(err)
        attempts.push(attempt)
      },
    })

    await vi.advanceTimersByTimeAsync(100)
    await promise

    expect(errors).toHaveLength(1)
    expect(errors[0].message).toBe('e1')
    expect(attempts).toEqual([1])
  })

  it('单次尝试超时抛出 RetryTimeoutError', async () => {
    const fn = vi.fn().mockImplementation(
      () => new Promise<string>(() => { /* never resolves */ })
    )

    // retries=0 保证只尝试一次，超时即抛出，不再因默认 shouldRetry 重试
    const promise = withRetry(fn, {
      retries: 0,
      delay: 100,
      timeout: 1000,
    })
    // 提前附加 handler 防止异步未处理 rejection 警告
    promise.catch(() => {})

    await vi.advanceTimersByTimeAsync(1000)
    await expect(promise).rejects.toBeInstanceOf(RetryTimeoutError)
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('retries 为负数时抛出参数错误', async () => {
    const fn = vi.fn().mockResolvedValue('ok')
    await expect(withRetry(fn, { retries: -1 })).rejects.toThrow()
  })
})

describe('withTimeout', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('在超时前完成则正常返回', async () => {
    const fn = vi.fn().mockResolvedValue('done')
    const result = await withTimeout(fn, 1000)
    expect(result).toBe('done')
  })

  it('超时后抛出 RetryTimeoutError', async () => {
    const fn = vi.fn().mockImplementation(
      () => new Promise<string>(() => { /* never resolves */ })
    )
    const promise = withTimeout(fn, 500)
    promise.catch(() => {})
    await vi.advanceTimersByTimeAsync(500)
    await expect(promise).rejects.toBeInstanceOf(RetryTimeoutError)
  })
})

describe('错误判断工具', () => {
  it('isNetworkError 识别 NetworkError 实例', () => {
    expect(isNetworkError(new NetworkError('网络错误'))).toBe(true)
  })

  it('isNetworkError 识别包含网络关键字的消息', () => {
    expect(isNetworkError(new Error('Network request failed'))).toBe(true)
    expect(isNetworkError(new Error('fetch failed'))).toBe(true)
    expect(isNetworkError(new Error('请求超时'))).toBe(true)
    expect(isNetworkError(new Error('timeout'))).toBe(true)
  })

  it('isNetworkError 不识别普通业务错误', () => {
    expect(isNetworkError(new Error('参数错误'))).toBe(false)
    expect(isNetworkError(new Error('not found'))).toBe(false)
  })

  it('isNonRetryableError 识别取消与参数错误', () => {
    expect(isNonRetryableError(new Error('User cancelled'))).toBe(true)
    expect(isNonRetryableError(new Error('用户取消'))).toBe(true)
    expect(isNonRetryableError(new Error('invalid argument'))).toBe(true)
    expect(isNonRetryableError(new Error('404 NotFound'))).toBe(true)
    expect(isNonRetryableError(new Error('权限不足'))).toBe(true)
  })

  it('defaultShouldRetry 网络错误返回 true', () => {
    expect(defaultShouldRetry(new NetworkError('网络断开'))).toBe(true)
    expect(defaultShouldRetry(new Error('网络异常'))).toBe(true)
  })

  it('defaultShouldRetry 参数/取消错误返回 false', () => {
    expect(defaultShouldRetry(new Error('参数错误'))).toBe(false)
    expect(defaultShouldRetry(new Error('User cancelled'))).toBe(false)
  })
})
