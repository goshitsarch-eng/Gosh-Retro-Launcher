import React, { forwardRef, InputHTMLAttributes } from 'react'

interface CheckboxProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label: string
}

export const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(
  ({ label, className = '', id, ...props }, ref) => {
    const inputId = id || `checkbox-${label.replace(/\s+/g, '-').toLowerCase()}`

    return (
      <label htmlFor={inputId} className={`win31-checkbox ${className}`}>
        <input ref={ref} type="checkbox" id={inputId} {...props} />
        <span className="checkmark" />
        <span className="label">{label}</span>
      </label>
    )
  }
)

Checkbox.displayName = 'Checkbox'
