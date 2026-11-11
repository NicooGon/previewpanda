const express = require('express')
const swaggerUi = require('swagger-ui-express')
const swaggerDocument = require('./swagger.json')

const app = express()

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument))

app.get('/health', (req, res) => {
  res.status(200).send('ok')
})

app.get('/error', (req, res) => {
  console.error(JSON.stringify({
    type: 'preview_test_error',
    route: '/error',
    pr: process.env.PR_NUMBER || 'NOT_CONFIGURED',
    commit: process.env.COMMIT_SHA || 'NOT_CONFIGURED'
  }))

  res.status(500).json({ message: 'Error de prueba' })
})

app.get('/', (req, res) => {
  res.json({
    app: 'PreviewPanda',
    pr: process.env.PR_NUMBER || 'NOT_CONFIGURED',
    commit: process.env.COMMIT_SHA || 'NOT_CONFIGURED',
    docs: '/api-docs'
  })
})

module.exports = app
