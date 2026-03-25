import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: process.env.VITE_PROXY_TARGET || 'http://backend:8080',
        changeOrigin: true,
        secure: false,
        ws: true,
      },
      '/ws': {
        target: process.env.VITE_WS_PROXY_TARGET || 'ws://backend:8080',
        changeOrigin: true,
        ws: true,
      },
    },
  },
})
