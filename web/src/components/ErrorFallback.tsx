interface ErrorFallbackProps {
  error: Error | null
  onReset: () => void
  onGoHome: () => void
}

/**
 * 错误降级 UI 组件
 * 从 error.message 提取首行作为用户可见消息，隐藏堆栈等技术细节。
 */
export default function ErrorFallback({ error, onReset, onGoHome }: ErrorFallbackProps) {
  const rawMessage = error?.message ?? ''
  const friendlyMessage = rawMessage
    ? rawMessage.split('\n')[0].slice(0, 200)
    : '应用遇到了一点问题，请尝试重新加载页面。'

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-bg">
      <div className="w-full max-w-md bg-card border border-border rounded-2xl p-6 sm:p-8 shadow-[0_20px_60px_rgba(0,0,0,0.5)] animate-fadeIn">
        <div className="flex flex-col items-center text-center">
          <div className="text-6xl mb-4">😵</div>
          <h2 className="text-xl sm:text-2xl font-bold text-text mb-2 flex items-center gap-2">
            <span>🛡️</span>
            <span>应用开小差了</span>
          </h2>
          <p className="text-sm text-text2 mb-6 break-words leading-relaxed">
            {friendlyMessage}
          </p>
          <div className="flex flex-col sm:flex-row gap-3 w-full">
            <button
              onClick={onReset}
              className="flex-1 px-6 py-3 rounded-xl font-bold text-white bg-gradient-to-r from-red to-red-dark border border-red/50 shadow-[0_4px_14px_rgba(255,107,107,0.4)] hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(255,107,107,0.5)] active:scale-95 transition-all duration-200 select-none"
            >
              🔄 重新加载页面
            </button>
            <button
              onClick={onGoHome}
              className="flex-1 px-6 py-3 rounded-xl font-bold text-text bg-card border border-border hover:bg-bg2 hover:border-text3 hover:-translate-y-0.5 active:scale-95 transition-all duration-200 select-none"
            >
              🏠 返回首页
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
