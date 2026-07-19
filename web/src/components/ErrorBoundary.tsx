import { Component, ErrorInfo, ReactNode } from 'react'
import ErrorFallback from './ErrorFallback'

interface ErrorBoundaryProps {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: ErrorInfo) => void
  resetKeys?: unknown[]
}

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
}

/**
 * React 错误边界组件
 * 捕获子组件树中的 JavaScript 错误，防止整个应用崩溃。
 * 必须是 class component（React 限制只有 class component 才能作为错误边界）。
 */
export default class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false, error: null }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    this.props.onError?.(error, errorInfo)
  }

  componentDidUpdate(prevProps: ErrorBoundaryProps): void {
    // 当 resetKeys 中的任意值变化时，自动重置错误状态
    if (this.state.hasError && prevProps.resetKeys !== this.props.resetKeys) {
      const prevKeys = prevProps.resetKeys ?? []
      const currKeys = this.props.resetKeys ?? []
      const changed =
        prevKeys.length !== currKeys.length ||
        prevKeys.some((key, index) => !Object.is(key, currKeys[index]))
      if (changed) {
        this.resetErrorBoundary()
      }
    }
  }

  /**
   * 重置错误状态，使子组件树重新渲染。
   * 可通过 ref 在外部调用：ref.current?.resetErrorBoundary()
   */
  resetErrorBoundary = (): void => {
    this.setState({ hasError: false, error: null })
  }

  render(): ReactNode {
    if (this.state.hasError) {
      if (this.props.fallback !== undefined) {
        return this.props.fallback
      }
      return (
        <ErrorFallback
          error={this.state.error}
          onReset={() => window.location.reload()}
          onGoHome={() => {
            window.location.href = '/'
          }}
        />
      )
    }
    return this.props.children
  }
}
