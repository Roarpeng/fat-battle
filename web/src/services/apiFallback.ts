/**
 * 服务降级链工具
 *
 * 按顺序尝试多个 provider，第一个成功即返回，全部失败则抛出最后一个错误。
 */

export interface FallbackOptions {
  /** 每次失败时的回调（已捕获错误，含 provider 索引） */
  onError?: (error: Error, providerIndex: number) => void
  /** 是否在尝试下一个 provider 前，跳过某些 provider（返回 true 表示跳过） */
  shouldSkipProvider?: (providerIndex: number) => boolean
}

export interface FallbackSuccess<T> {
  /** 成功返回的值 */
  value: T
  /** 成功的 provider 索引 */
  providerIndex: number
}

export class AllProvidersFailedError extends Error {
  public readonly errors: Error[]
  constructor(errors: Error[], message = '所有 provider 均失败') {
    super(message)
    this.name = 'AllProvidersFailedError'
    this.errors = errors
    Object.setPrototypeOf(this, AllProvidersFailedError.prototype)
  }
}

/**
 * 按顺序尝试多个 provider，第一个成功即返回，全部失败则抛出最后一个错误。
 *
 * @param providers provider 函数数组（按优先级从高到低）
 * @param options 降级配置
 * @example
 * ```ts
 * const result = await withFallback([
 *   () => fetchFromPrimary(),
 *   () => fetchFromCache(),
 *   () => Promise.resolve(localData),
 * ], (err, i) => console.warn(`provider ${i} 失败`, err))
 * ```
 */
export async function withFallback<T>(
  providers: Array<() => Promise<T>>,
  onError?: (error: Error, providerIndex: number) => void
): Promise<T>
export async function withFallback<T>(
  providers: Array<() => Promise<T>>,
  options?: FallbackOptions
): Promise<T>
export async function withFallback<T>(
  providers: Array<() => Promise<T>>,
  optsOrOnError?: ((error: Error, providerIndex: number) => void) | FallbackOptions
): Promise<T> {
  if (!Array.isArray(providers) || providers.length === 0) {
    throw new Error('withFallback: 至少需要一个 provider')
  }

  const options: FallbackOptions =
    typeof optsOrOnError === 'function'
      ? { onError: optsOrOnError }
      : (optsOrOnError ?? {})

  const errors: Error[] = []
  let lastError: Error | undefined

  for (let i = 0; i < providers.length; i++) {
    if (options.shouldSkipProvider?.(i)) {
      continue
    }
    try {
      return await providers[i]()
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err))
      errors.push(lastError)
      options.onError?.(lastError, i)
    }
  }

  if (errors.length === 0) {
    throw new Error('withFallback: 没有 provider 被执行（可能全部被跳过）')
  }
  throw lastError ?? new AllProvidersFailedError(errors)
}

/**
 * 与 withFallback 类似，但同时返回成功的 provider 索引
 */
export async function withFallbackDetail<T>(
  providers: Array<() => Promise<T>>,
  options: FallbackOptions = {}
): Promise<FallbackSuccess<T>> {
  if (!Array.isArray(providers) || providers.length === 0) {
    throw new Error('withFallbackDetail: 至少需要一个 provider')
  }

  const errors: Error[] = []
  let lastError: Error | undefined

  for (let i = 0; i < providers.length; i++) {
    if (options.shouldSkipProvider?.(i)) {
      continue
    }
    try {
      const value = await providers[i]()
      return { value, providerIndex: i }
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err))
      errors.push(lastError)
      options.onError?.(lastError, i)
    }
  }

  if (errors.length === 0) {
    throw new Error('withFallbackDetail: 没有 provider 被执行（可能全部被跳过）')
  }
  throw lastError ?? new AllProvidersFailedError(errors)
}
