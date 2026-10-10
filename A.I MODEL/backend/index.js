require('dotenv').config();

const express = require('express');
const cors = require('cors');
const agentRoutes = require('./routes/agentRoutes');
const chatRoutes = require('./routes/chatRoutes');
const { initializeDatabase } = require('./data/db');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'AI Model backend is running' });
});

app.use('/api/agents', agentRoutes);
app.use('/api/chat', chatRoutes);

const port = process.env.PORT || 4000;

initializeDatabase()
  .then(() => {
    app.listen(port, () => {
      console.log(`Server listening on http://localhost:${port}`);
    });
  })
  .catch((err) => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
  });
