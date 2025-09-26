const express = require('express');
const bodyParser = require('body-parser');
const sqlite3 = require('sqlite3').verbose();
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const csrf = require('csurf');
const app = express();

// Security middleware
app.use(helmet());
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
}));

// Body parsing middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// CSRF protection (only for forms, skip for API endpoints)
const csrfProtection = csrf({ cookie: true });
app.use(csrfProtection);

const DBFILE = './users.db';

const db = new sqlite3.Database(DBFILE);
db.serialize(() => {
  db.run("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)");
  db.run("INSERT OR IGNORE INTO users (id, username, password) VALUES (1,'alice','password123')");
});

app.get('/user', (req, res) => {
  const id = req.query.id || '1';
  // Use parameterized queries to prevent SQL injection
  const sql = `SELECT id, username FROM users WHERE id = ?;`;
  db.all(sql, [id], (err, rows) => {
    if (err) return res.status(500).send("DB error");
    res.json(rows);
  });
});

app.get('/greet', (req, res) => {
  const name = req.query.name || 'guest';
  // Escape HTML to prevent XSS
  const escapedName = name.replace(/[&<>"']/g, function(match) {
    switch(match) {
      case '&': return '&amp;';
      case '<': return '&lt;';
      case '>': return '&gt;';
      case '"': return '&quot;';
      case "'": return '&#39;';
      default: return match;
    }
  });
  res.send(`<h1>Hello ${escapedName}</h1>`);
});

app.get('/', (req, res) => {
  res.send('<h2>DevSecOps Lab App</h2><p>Try /user?id=1 and /greet?name=xyz</p>');
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Vulnerable app listening on port ${port}`);
});
