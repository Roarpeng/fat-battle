import { ButtonHTMLAttributes, ReactNode, useState } from 'react'

type ButtonVariant = 'primary' | 'secondary' | 'gold' | 'green' | 'purple'
type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
  icon?: ReactNode
  fullWidth?: boolean
  loading?: boolean
}

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-gradient-to-r from-red to-red-dark text-white border-red/50 shadow-[0_4px_14px_rgba(255,107,107,0.4)] hover:shadow-[0_6px_20px_rgba(255,107,107,0.5)]',
  secondary:
    'bg-card text-text border-border hover:bg-bg2 hover:border-text3',
  gold:
    'bg-gradient-to-r from-gold to-gold-dark text-bg border-gold/50 shadow-[0_4px_14px_rgba(255,217,61,0.4)] hover:shadow-[0_6px_20px_rgba(255,217,61,0.5)]',
  green:
    'bg-gradient-to-r from-green to-green-dark text-white border-green/50 shadow-[0_4px_14px_rgba(46,204,113,0.4)] hover:shadow-[0_6px_20px_rgba(46,204,113,0.5)]',
  purple:
    'bg-gradient-to-r from-purple to-purple-dark text-white border-purple/50 shadow-[0_4px_14px_rgba(102,126,234,0.4)] hover:shadow-[0_6px_20px_rgba(102,126,234,0.5)]',
}

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'px-4 py-2 text-sm gap-1.5',
  md: 'px-6 py-3 text-base gap-2',
  lg: 'px-8 py-4 text-lg gap-2.5',
}

export default function Button({
  variant = 'primary',
  size = 'md',
  icon,
  fullWidth = false,
  loading = false,
  disabled,
  className = '',
  children,
  onMouseDown,
  onMouseUp,
  onTouchStart,
  onTouchEnd,
  ...props
}: ButtonProps) {
  const [pressed, setPressed] = useState(false)

  const baseStyle =
    'relative font-bold rounded-xl border transition-all duration-200 flex items-center justify-center select-none overflow-hidden'
  const disabledStyle = 'opacity-50 cursor-not-allowed'
  const hoverStyle = 'hover:-translate-y-0.5'
  const pressStyle = pressed && !disabled && !loading ? 'scale-95' : ''

  const handlePressStart = () => !disabled && !loading && setPressed(true)
  const handlePressEnd = () => setPressed(false)

  return (
    <button
      disabled={disabled || loading}
      className={`
        ${baseStyle}
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${fullWidth ? 'w-full' : ''}
        ${disabled || loading ? disabledStyle : hoverStyle}
        ${pressStyle}
        ${className}
      `}
      onMouseDown={(e) => { handlePressStart(); onMouseDown?.(e) }}
      onMouseUp={(e) => { handlePressEnd(); onMouseUp?.(e) }}
      onMouseLeave={handlePressEnd}
      onTouchStart={(e) => { handlePressStart(); onTouchStart?.(e) }}
      onTouchEnd={(e) => { handlePressEnd(); onTouchEnd?.(e) }}
      {...props}
    >
      {loading ? (
        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
      ) : (
        <>
          {icon && <span className="shrink-0">{icon}</span>}
          {children}
        </>
      )}
    </button>
  )
}
