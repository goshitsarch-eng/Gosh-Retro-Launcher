import { mount } from 'svelte'
import App from './App.svelte'
import { tauriAPI } from './lib/tauri-api'
import './styles/win31.css'
import './styles/menu.css'
import './styles/dialog.css'
import './styles/mdi.css'

// Set up global electronAPI for backward compatibility
window.electronAPI = tauriAPI

const app = mount(App, {
  target: document.getElementById('root')!
})

export default app
