const express = require('express');
const router = express.Router();
const { getAgents, getAgentById } = require('../data/db');

router.get('/', async (req, res) => {
  try {
    const agents = await getAgents();
    res.json(agents);
  } catch (err) {
    console.error('Failed to load agents:', err);
    res.status(500).json({ error: 'Failed to load agents' });
  }
});

router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);

  try {
    const agent = await getAgentById(id);

    if (!agent) {
      return res.status(404).json({ error: 'Agent not found' });
    }

    res.json(agent);
  } catch (err) {
    console.error('Failed to load agent:', err);
    res.status(500).json({ error: 'Failed to load agent' });
  }
});

module.exports = router;
