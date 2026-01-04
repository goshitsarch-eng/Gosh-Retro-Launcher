import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],

  // Tauri expects a fixed port for development
  server: {
    port: 5173,
    strictPort: true,
    watch: {
      ignored: ['**/src-tauri/**']
    }
  },

  // Prevent Vite from obscuring Rust errors
  clearScreen: false,

  // Tauri expects this env prefix
  envPrefix: ['VITE_', 'TAURI_'],

  build: {
    // Tauri uses Chromium on Windows and WebKit on macOS and Linux
    target: process.env.TAURI_PLATFORM === 'windows' ? 'chrome105' : 'safari14',
    // Don't minify for debug builds
    minify: !process.env.TAURI_DEBUG ? 'esbuild' : false,
    // Produce sourcemaps for debug builds
    sourcemap: !!process.env.TAURI_DEBUG,
    outDir: 'dist'
  },

  // Use the renderer directory as root
  root: 'src/renderer',

  resolve: {
    alias: {
      '@': resolve(__dirname, 'src/renderer/src'),
      '@shared': resolve(__dirname, 'src/shared')
    }
  }
})
