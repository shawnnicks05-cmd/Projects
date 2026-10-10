const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const dbPath = path.join(__dirname, 'agents.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Failed to open database:', err.message);
    process.exit(1);
  }
});

function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) {
        reject(err);
      } else {
        resolve(this);
      }
    });
  });
}

function get(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
}

function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

const defaultAgents = [
  {
    id: 1,
    name: 'Fitness A.I',
    description: 'Routine optimization, metric tracking, and caloric management.',
  },
  {
    id: 2,
    name: 'Health A.I',
    description: 'Wellness, symptom tracking, and healthy habit planning.',
  },
  {
    id: 3,
    name: 'School A.I',
    description: 'Topic breakdowns, homework help, and study schedules.',
  },
  {
    id: 4,
    name: 'Maps A.I',
    description: 'Local travel suggestions, routing, and points of interest.',
  },
  {
    id: 5,
    name: 'Code Helper',
    description: 'Debugging, architectural review, and code assistance.',
  },
  {
    id: 6,
    name: 'Emergency A.I',
    description: 'Immediate safety guidance and emergency instructions.',
  },
  {
    id: 7,
    name: 'Language Learner A.I',
    description: 'Conversation practice, vocabulary, and grammar help.',
  },
];

async function initializeDatabase() {
  await run(
    `CREATE TABLE IF NOT EXISTS agents (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL
    )`
  );

  const row = await get('SELECT COUNT(*) AS count FROM agents');
  if (!row || row.count === 0) {
    for (const agent of defaultAgents) {
      await run('INSERT INTO agents (id, name, description) VALUES (?, ?, ?)', [
        agent.id,
        agent.name,
        agent.description,
      ]);
    }
  }
}

function getAgents() {
  return all('SELECT * FROM agents ORDER BY id');
}

function getAgentById(id) {
  return get('SELECT * FROM agents WHERE id = ?', [id]);
}

module.exports = {
  initializeDatabase,
  getAgents,
  getAgentById,
};
