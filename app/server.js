const express = require('express')
const swaggerUi = require('swagger-ui-express')
const swaggerDocument = require('./swagger.json')

const app = express()
const port = process.env.PORT || 8080

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument))

app.get('/health', (req, res) => {
  res.status(200).send('ok')
})

app.get('/error', (req, res) => {
  res.status(500).json({ message: 'Error de prueba' })
})

app.get('/', (req, res) => {
  res.json({
    app: 'PreviewPanda',
    pr: process.env.PR_NUMBER || 'local',
    commit: process.env.COMMIT_SHA || 'dev',
    docs: '/api-docs'
  })
})

app.listen(port, '0.0.0.0', () => {
  console.log(`PreviewPanda escuchando en el puerto ${port}`)
})
