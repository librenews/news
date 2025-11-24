import express from 'express';

const app = express();
const PORT = process.env.PORT || 6000;
const HOST = process.env.HOST || '0.0.0.0';

app.use(express.json());

// Health check endpoints
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'skywire' });
});

app.get('/health/ready', (req, res) => {
  res.json({ status: 'ready' });
});

app.get('/health/live', (req, res) => {
  res.json({ status: 'alive' });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Skywire',
    version: '0.1.0',
    status: 'running'
  });
});

// API endpoint
app.get('/api/v1', (req, res) => {
  res.json({
    message: 'Skywire API',
    version: '0.1.0'
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Skywire server running on http://${HOST}:${PORT}`);
});

