import React from 'react'

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  ErrorBoundaryState
> {
  constructor(props: { children: React.ReactNode }) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, info: React.ErrorInfo): void {
    console.error('Uncaught error in renderer:', error, info.componentStack)
  }

  render(): React.ReactNode {
    if (this.state.hasError) {
      return (
        <div style={{
          padding: 32,
          fontFamily: '"MS Sans Serif", Arial, sans-serif',
          backgroundColor: '#008080',
          color: '#ffffff',
          height: '100vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          <div style={{
            backgroundColor: '#c0c0c0',
            color: '#000000',
            border: '2px outset #ffffff',
            padding: 24,
            maxWidth: 480
          }}>
            <h2 style={{ margin: '0 0 12px', fontSize: 14 }}>Program Manager - Error</h2>
            <p style={{ fontSize: 12, margin: '0 0 12px' }}>
              An unexpected error occurred. Please restart the application.
            </p>
            <p style={{ fontSize: 11, color: '#808080', margin: '0 0 16px', wordBreak: 'break-word' }}>
              {this.state.error?.message}
            </p>
            <button
              onClick={() => window.location.reload()}
              style={{
                padding: '4px 16px',
                fontSize: 12,
                cursor: 'pointer'
              }}
            >
              Restart
            </button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
