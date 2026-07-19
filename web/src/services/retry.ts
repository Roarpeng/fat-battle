/**
 * 通用错误重试工具
 *
 * 提供：
 * - 可配置的指数/线性退避重试
 * - shouldRetry 谓词判断哪些错误值得重试
 * - 单次尝试超时处理
 * - 常见错误类型与判断工具
 */

export interface RetryOptions {
  /** 最大重试次数，默认 3（即首次执行 + retries 次重试） */
  retries?: number
  /** 初始延迟(ms)，默认 1000 */
  delay?: number
  /** 退避策略，默认 'exponential' */
  backoff?: 'linear' | 'exponential'
  /** 退避因子，默认 2 */
  factor?: number
  /** 单次尝试超时(ms)，超时则抛出 RetryTimeoutError；不设置则不启用 */
  timeout?: number
  /** 每次重试前的回调（已捕获错误） */
  onRetry?: (error: Error, attempt: number) => void
  /** 判断错误是否应该重试，默认全部重试 */
  shouldRetry?: (error: Error) => boolean
}

/** 操作超时错误 */
export class RetryTimeoutError extends Error {
  constructor(message = '操作超时') {
    super(message)
    this.name = 'RetryTimeoutError'
    Object.setPrototypeOf(this, RetryTimeoutError.prototype)
  }
}

/** 网络错误（值得重试） */
export class NetworkError extends Error {
  constructor(message = '网络错误') {
    super(message)
    this.name = 'NetworkError'
    Object.setPrototypeOf(this, NetworkError.prototype)
  }
}

const sleep = (ms: number): Promise<void> =>
  new Promise(resolve => setTimeout(resolve, ms))

/**
 * 计算第 attempt 次重试的等待延迟(ms)
 * - linear: delay * attempt * factor
 * - exponential: delay * factor^(attempt-1)
 */
export function computeDelay(
  attempt: number,
  baseDelay: number,
  backoff: 'linear' | 'exponential',
  factor: number
): number {
  if (backoff === 'linear') {
    return baseDelay * attempt * factor
  }
  return baseDelay * Math.pow(factor, attempt - 1)
}

/**
 * 为单次 Promise 调用附加超时
 */
export function withTimeout<T>(
  fn: () => Promise<T>,
  timeoutMs: number,
  message = '操作超时'
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    let settled = false
    const timer = setTimeout(() => {
      if (!settled) {
        settled = true
        reject(new RetryTimeoutError(message))
      }
    }, timeoutMs)

    fn()
      .then(result => {
        if (!settled) {
          settled = true
          clearTimeout(timer)
          resolve(result)
        }
      })
      .catch(err => {
        if (!settled) {
          settled = true
          clearTimeout(timer)
          reject(err)
        }
      })
  })
}

/**
 * 判断是否为网络错误（值得重试）
 */
export function isNetworkError(error: Error): boolean {
  if (error instanceof NetworkError) return true
  const msg = (error.message || '').toLowerCase()
  return (
    msg.includes('network') ||
    msg.includes('fetch') ||
    msg.includes('网络') ||
    msg.includes('timeout') ||
    msg.includes('超时') ||
    msg.includes('econnreset') ||
    msg.includes('econnrefused') ||
    msg.includes('etimedout')
  )
}

/**
 * 判断是否为不可重试错误（参数错误、用户取消、404 等）
 */
export function isNonRetryableError(error: Error): boolean {
  const msg = (error.message || '').toLowerCase()
  if (msg.includes('cancel') || msg.includes('取消')) return true
  if (msg.includes('user cancelled')) return true
  if (msg.includes('invalid') || msg.includes('参数错误') || msg.includes('argument')) return true
  if (msg.includes('notfound') || msg.includes('404')) return true
  if (msg.includes('permission') || msg.includes('权限')) return true
  return false
}

/**
 * 默认的 shouldRetry 实现：网络错误重试，参数错误/取消不重试
 */
export function defaultShouldRetry(error: Error): boolean {
  if (isNonRetryableError(error)) return false
  if (isNetworkError(error)) return true
  return true
}

/**
 * 通用重试函数
 *
 * @param fn 要执行的异步操作
 * @param options 重试配置
 * @example
 * ```ts
 * const data = await withRetry(() => fetch(url).then(r => r.json()), {
 *   retries: 3,
 *   backoff: 'exponential',
 *   shouldRetry: (err) => isNetworkError(err),
 * })
 * ```
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    retries = 3,
    delay = 1000,
    backoff = 'exponential',
    factor = 2,
    timeout,
    onRetry,
    shouldRetry = defaultShouldRetry,
  } = options

  if (retries < 0) {
    throw new Error('withRetry: retries 不能为负数')
  }

  const executeOnce = (): Promise<T> => {
    if (typeof timeout === 'number' && timeout > 0) {
      return withTimeout(fn, timeout)
    }
    return fn()
  }

  let lastError: Error | undefined
  const totalAttempts = retries + 1

  for (let attempt = 1; attempt <= totalAttempts; attempt++) {
    try {
      return await executeOnce()
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err))
      const isLastAttempt = attempt >= totalAttempts
      if (isLastAttempt) {
        throw lastError
      }
      if (!shouldRetry(lastError)) {
        throw lastError
      }
      const waitMs = computeDelay(attempt, delay, backoff, factor)
      onRetry?.(lastError, attempt)
      await sleep(waitMs)
    }
  }

  // 理论上不会到达
  throw lastError ?? new Error('withRetry: 未捕获的错误')
}
