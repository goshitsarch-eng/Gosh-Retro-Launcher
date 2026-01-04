import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import { tauriAPI } from './lib/tauri-api'
import './styles/win31.css'
import './styles/menu.css'
import './styles/dialog.css'
import './styles/mdi.css'

// Set up global electronAPI for backward compatibility
window.electronAPI = tauriAPI

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
