import '@testing-library/jest-dom/vitest'
import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, fireEvent, act } from '@testing-library/react'
import Toast, { ToastItem } from '../Toast'
import { useToast } from '../ToastContainer'

function getCardByText(text: string) {
  return screen.getByText(text).closest('[role="status"]') as HTMLElement
}

describe('Toast - 四种类型渲染', () => {
  it('success 类型使用绿色样式', () => {
    render(<Toast message="成功" type="success" visible={true} />)
    const card = screen.getByRole('status')
    expect(card.className).toContain('text-green')
    expect(card.className).toContain('border-green')
    expect(screen.getByText('成功')).toBeInTheDocument()
  })

  it('warning 类型使用橙色（gold）样式', () => {
    render(<Toast message="警告" type="warning" visible={true} />)
    const card = screen.getByRole('status')
    expect(card.className).toContain('text-gold')
    expect(card.className).toContain('border-gold')
  })

  it('error 类型使用红色样式', () => {
    render(<Toast message="错误" type="error" visible={true} />)
    const card = screen.getByRole('status')
    expect(card.className).toContain('text-red')
    expect(card.className).toContain('border-red')
  })

  it('info 类型使用蓝色样式', () => {
    render(<Toast message="信息" type="info" visible={true} />)
    const card = screen.getByRole('status')
    expect(card.className).toContain('text-blue')
    expect(card.className).toContain('border-blue')
  })

  it('默认类型为 info', () => {
    render(<Toast message="默认" visible={true} />)
    const card = screen.getByRole('status')
    expect(card.className).toContain('text-blue')
  })
})

describe('Toast - 堆叠显示', () => {
  it('同时渲染多个 toast', () => {
    const toasts: ToastItem[] = [
      { id: '1', message: '第一条', type: 'success' },
      { id: '2', message: '第二条', type: 'warning' },
      { id: '3', message: '第三条', type: 'error' },
    ]
    render(<Toast toasts={toasts} />)
    expect(screen.getByText('第一条')).toBeInTheDocument()
    expect(screen.getByText('第二条')).toBeInTheDocument()
    expect(screen.getByText('第三条')).toBeInTheDocument()
  })

  it('堆叠中每种类型样式正确', () => {
    const toasts: ToastItem[] = [
      { id: 's', message: 'success-msg', type: 'success' },
      { id: 'w', message: 'warning-msg', type: 'warning' },
      { id: 'e', message: 'error-msg', type: 'error' },
      { id: 'i', message: 'info-msg', type: 'info' },
    ]
    render(<Toast toasts={toasts} />)
    expect(getCardByText('success-msg').className).toContain('text-green')
    expect(getCardByText('warning-msg').className).toContain('text-gold')
    expect(getCardByText('error-msg').className).toContain('text-red')
    expect(getCardByText('info-msg').className).toContain('text-blue')
  })

  it('空列表不渲染任何 toast', () => {
    const { container } = render(<Toast toasts={[]} />)
    expect(container.querySelectorAll('[role="status"]')).toHaveLength(0)
  })
})

describe('Toast - 自动消失', () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it('duration 后调用 onDismiss', () => {
    vi.useFakeTimers()
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'auto-1', message: '将消失', type: 'success', duration: 1000 },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)
    expect(onDismiss).not.toHaveBeenCalled()

    act(() => {
      vi.advanceTimersByTime(1000)
    })
    expect(onDismiss).toHaveBeenCalledTimes(1)
    expect(onDismiss).toHaveBeenCalledWith('auto-1')
  })

  it('duration 未到时不消失', () => {
    vi.useFakeTimers()
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'auto-2', message: '将消失', type: 'info', duration: 2000 },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)

    act(() => {
      vi.advanceTimersByTime(1999)
    })
    expect(onDismiss).not.toHaveBeenCalled()

    act(() => {
      vi.advanceTimersByTime(1)
    })
    expect(onDismiss).toHaveBeenCalledWith('auto-2')
  })

  it('默认 duration 为 3000ms', () => {
    vi.useFakeTimers()
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'default-dur', message: '默认时长', type: 'info' },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)

    act(() => {
      vi.advanceTimersByTime(2999)
    })
    expect(onDismiss).not.toHaveBeenCalled()

    act(() => {
      vi.advanceTimersByTime(1)
    })
    expect(onDismiss).toHaveBeenCalledWith('default-dur')
  })

  it('每个 toast 独立计时', () => {
    vi.useFakeTimers()
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'fast', message: '快', type: 'success', duration: 500 },
      { id: 'slow', message: '慢', type: 'error', duration: 2000 },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)

    act(() => {
      vi.advanceTimersByTime(500)
    })
    expect(onDismiss).toHaveBeenCalledTimes(1)
    expect(onDismiss).toHaveBeenCalledWith('fast')

    act(() => {
      vi.advanceTimersByTime(1500)
    })
    expect(onDismiss).toHaveBeenCalledTimes(2)
    expect(onDismiss).toHaveBeenCalledWith('slow')
  })
})

describe('Toast - 关闭按钮', () => {
  it('点击关闭按钮调用 onDismiss', () => {
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'close-1', message: '可关闭', type: 'info' },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)
    fireEvent.click(screen.getByLabelText('关闭'))
    expect(onDismiss).toHaveBeenCalledTimes(1)
    expect(onDismiss).toHaveBeenCalledWith('close-1')
  })

  it('堆叠中每个 toast 都有独立关闭按钮', () => {
    const onDismiss = vi.fn()
    const toasts: ToastItem[] = [
      { id: 'a', message: '甲', type: 'success' },
      { id: 'b', message: '乙', type: 'error' },
    ]
    render(<Toast toasts={toasts} onDismiss={onDismiss} />)
    const buttons = screen.getAllByLabelText('关闭')
    expect(buttons).toHaveLength(2)

    fireEvent.click(buttons[0])
    expect(onDismiss).toHaveBeenCalledWith('a')
    fireEvent.click(buttons[1])
    expect(onDismiss).toHaveBeenCalledWith('b')
    expect(onDismiss).toHaveBeenCalledTimes(2)
  })

  it('单 toast 模式点击关闭调用 onClose', () => {
    const onClose = vi.fn()
    render(<Toast message="单条" type="info" visible={true} onClose={onClose} />)
    fireEvent.click(screen.getByLabelText('关闭'))
    expect(onClose).toHaveBeenCalledTimes(1)
  })
})

describe('Toast - 向后兼容', () => {
  it('visible=false 时不渲染', () => {
    render(<Toast message="隐藏" type="info" visible={false} />)
    expect(screen.queryByText('隐藏')).toBeNull()
  })

  it('visible=true 时渲染', () => {
    render(<Toast message="显示" type="info" visible={true} />)
    expect(screen.getByText('显示')).toBeInTheDocument()
  })

  it('非受控模式自动显示并消失', () => {
    vi.useFakeTimers()
    const onClose = vi.fn()
    render(<Toast message="自动" type="info" duration={1000} onClose={onClose} />)
    expect(screen.getByText('自动')).toBeInTheDocument()

    act(() => {
      vi.advanceTimersByTime(1000)
    })
    expect(onClose).toHaveBeenCalledTimes(1)
    vi.useRealTimers()
  })
})

describe('useToast hook', () => {
  it('showToast 添加 toast，dismissToast 移除 toast', () => {
    function Harness() {
      const { toasts, showToast, dismissToast } = useToast()
      return (
        <div>
          <button onClick={() => showToast('保存成功', 'success')}>show</button>
          <button onClick={() => dismissToast(toasts[0]?.id ?? '')}>dismiss</button>
          <ul>
            {toasts.map((t) => (
              <li key={t.id}>{t.message}</li>
            ))}
          </ul>
        </div>
      )
    }
    render(<Harness />)

    fireEvent.click(screen.getByText('show'))
    expect(screen.getByText('保存成功')).toBeInTheDocument()

    fireEvent.click(screen.getByText('dismiss'))
    expect(screen.queryByText('保存成功')).toBeNull()
  })

  it('showToast 支持自定义 duration', () => {
    vi.useFakeTimers()
    function Harness({ onReady }: { onReady: (api: ReturnType<typeof useToast>) => void }) {
      const api = useToast()
      onReady(api)
      return (
        <ul>
          {api.toasts.map((t) => (
            <li key={t.id}>{t.message}</li>
          ))}
        </ul>
      )
    }
    let api!: ReturnType<typeof useToast>
    render(<Harness onReady={(a) => (api = a)} />)

    act(() => {
      api.showToast('网络错误', 'error', 5000)
    })
    expect(screen.getByText('网络错误')).toBeInTheDocument()
    expect(api.toasts[0].duration).toBe(5000)
    vi.useRealTimers()
  })

  it('dismissToast 对不存在的 id 安全无副作用', () => {
    function Harness({ onReady }: { onReady: (api: ReturnType<typeof useToast>) => void }) {
      const api = useToast()
      onReady(api)
      return (
        <ul>
          {api.toasts.map((t) => (
            <li key={t.id}>{t.message}</li>
          ))}
        </ul>
      )
    }
    let api!: ReturnType<typeof useToast>
    render(<Harness onReady={(a) => (api = a)} />)

    act(() => {
      api.showToast('a', 'info')
      api.dismissToast('not-exist')
    })
    expect(api.toasts).toHaveLength(1)
    expect(api.toasts[0].message).toBe('a')
  })

  it('返回新增 toast 的 id', () => {
    function Harness({ onReady }: { onReady: (api: ReturnType<typeof useToast>) => void }) {
      const api = useToast()
      onReady(api)
      return null
    }
    let api!: ReturnType<typeof useToast>
    render(<Harness onReady={(a) => (api = a)} />)

    let id: string | undefined
    act(() => {
      id = api.showToast('msg', 'info')
    })
    expect(id).toBeTypeOf('string')
    expect(api.toasts[0].id).toBe(id)
  })
})
