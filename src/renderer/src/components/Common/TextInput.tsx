import React, { forwardRef, InputHTMLAttributes } from 'react'

interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {}

export const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
  ({ className = '', ...props }, ref) => {
    return (
      <input
        ref={ref}
        type="text"
        className={`win31-input ${className}`}
        {...props}
      />
    )
  }
)

TextInput.displayName = 'TextInput'
