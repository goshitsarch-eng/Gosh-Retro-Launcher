import React, { forwardRef, ButtonHTMLAttributes } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  isDefault?: boolean
  small?: boolean
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ children, isDefault = false, small = false, className = '', ...props }, ref) => {
    const classes = [
      small ? 'win31-control-button' : 'win31-button',
      isDefault ? 'default' : '',
      className
    ].filter(Boolean).join(' ')

    return (
      <button ref={ref} className={classes} {...props}>
        {children}
      </button>
    )
  }
)

Button.displayName = 'Button'
