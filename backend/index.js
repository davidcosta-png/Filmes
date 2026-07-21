const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// Use SQLite for durable storage so credentials survive server restarts/crashes
const path = require('path');
const Database = require('better-sqlite3');
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);
const DB_FILE = path.join(DATA_DIR, 'users.db');
const db = new Database(DB_FILE);

// initialize schema
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  passwordHash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  paused INTEGER NOT NULL DEFAULT 0,
  refreshToken TEXT,
  refreshTokenExpiry INTEGER
);
`);

const JWT_SECRET = process.env.JWT_SECRET || 'replace_with_secure_secret_in_production';
const app = express();
app.use(cors());
app.use(bodyParser.json());

// simple health endpoint used by CI to detect backend readiness
app.get('/auth/health', (req, res) => res.json({ ok: true }));

function findUserByUsername(username){
  const row = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
  return row;
}
function findUserByRefreshToken(token){
  if(!token) return null;
  const row = db.prepare('SELECT * FROM users WHERE refreshToken = ?').get(token);
  return row;
}

function saveRefreshTokenForUser(username, refreshToken, expiry){
  db.prepare('UPDATE users SET refreshToken = ?, refreshTokenExpiry = ? WHERE username = ?').run(refreshToken, expiry, username);
}

function revokeRefreshToken(refreshToken){
  db.prepare('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE refreshToken = ?').run(refreshToken);
}

// Middleware: verify JWT and attach user; also block paused users
function verifyToken(req, res, next){
  const auth = req.headers['authorization'];
  if(!auth) return res.status(401).json({ error: 'No token provided' });
  const parts = auth.split(' ');
  if(parts.length !== 2) return res.status(401).json({ error: 'Invalid auth header' });
  const token = parts[1];
  try{
    const decoded = jwt.verify(token, JWT_SECRET);
    // check paused status
    const u = findUserByUsername(decoded.username);
    if(u && u.paused) return res.status(403).json({ error: 'User is paused' });
    req.user = decoded;
    next();
  } catch(e){
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function adminOnly(req, res, next){
  if(!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'Admin required' });
  next();
}

app.post('/auth/login', async (req, res) => {
  const { username, password } = req.body;
  const user = findUserByUsername(username);
  if(!user) return res.status(401).json({ error: 'Invalid credentials' });
  const match = await bcrypt.compare(password, user.passwordHash);
  if(!match) return res.status(401).json({ error: 'Invalid credentials' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  // generate refresh token
  const refreshToken = crypto.randomBytes(32).toString('hex');
  const expiry = Date.now() + 7 * 24 * 60 * 60 * 1000; // 7 days
  saveRefreshTokenForUser(user.username, refreshToken, expiry);
  res.json({ token, refreshToken });
});

app.get('/auth/me', verifyToken, (req, res) => {
  const u = req.user || {};
  res.json({ username: u.username, role: u.role });
});

app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  const user = findUserByRefreshToken(refreshToken);
  if(!user) return res.status(401).json({ error: 'Invalid refresh token' });
  if(!user.refreshTokenExpiry || Date.now() > user.refreshTokenExpiry) return res.status(401).json({ error: 'Refresh token expired' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  // rotate refresh token
  const newRefresh = crypto.randomBytes(32).toString('hex');
  const newExpiry = Date.now() + 7 * 24 * 60 * 60 * 1000;
  saveRefreshTokenForUser(user.username, newRefresh, newExpiry);
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  res.json({ token, refreshToken: newRefresh });
});

app.post('/auth/logout', (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  revokeRefreshToken(refreshToken);
  res.json({ ok: true });
});

// Protected user management routes (admin only)
app.get('/users', verifyToken, adminOnly, (req, res) => {
  const rows = db.prepare('SELECT username, role, paused FROM users').all();
  res.json(rows.map(r => ({ username: r.username, role: r.role, paused: !!r.paused })));
});

app.post('/users', verifyToken, adminOnly, async (req, res) => {
  const { username, password, role } = req.body;
  if(!username || !password) return res.status(400).json({ error: 'username and password required' });
  const exists = findUserByUsername(username);
  if(exists) return res.status(400).json({ error: 'already exists' });
  const hash = await bcrypt.hash(password, 10);
  db.prepare('INSERT INTO users (username, passwordHash, role, paused) VALUES (?, ?, ?, 0)').run(username, hash, role || 'user');
  res.status(201).json({ ok: true });
});

app.post('/users/:username/pause', verifyToken, adminOnly, (req, res) => {
  const { username } = req.params;
  const u = findUserByUsername(username);
  if(!u) return res.status(404).json({ error: 'not found' });
  const paused = !!req.body.paused;
  db.prepare('UPDATE users SET paused = ? WHERE username = ?').run(paused ? 1 : 0, username);
  if(paused){ db.prepare('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE username = ?').run(username); }
  res.json({ ok: true });
});

app.delete('/users/:username', verifyToken, adminOnly, (req, res) => {
  const { username } = req.params;
  const info = db.prepare('DELETE FROM users WHERE username = ?').run(username);
  if(info.changes === 0) return res.status(404).json({ error: 'not found' });
  res.json({ ok: true });
});

// Admin seed: create admin from env ADMIN_USER/ADMIN_PASS if provided; otherwise create default Davi/1234 only if no admin exists
(function ensureAdmin(){
  const adminExists = db.prepare('SELECT 1 FROM users WHERE role = "admin" LIMIT 1').get();
  if(!adminExists) {
    const adminUser = process.env.ADMIN_USER || 'Davi';
    const adminPass = process.env.ADMIN_PASS || '1234';
    bcrypt.hash(adminPass, 10).then(h => {
      db.prepare('INSERT INTO users (username, passwordHash, role, paused) VALUES (?, ?, "admin", 0)').run(adminUser, h);
      console.log(`Admin user created: ${adminUser} (change password)`) ;
    }).catch(err => console.error('Error creating default admin', err));
  }
})();

// Simple DB backup endpoint (admin only) - creates a timestamped copy under ./data/backups
app.post('/admin/backup', verifyToken, adminOnly, (req, res) => {
  try{
    const backupsDir = path.join(DATA_DIR, 'backups');
    if(!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir);
    const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
    const dest = path.join(backupsDir, `users-${timestamp}.db`);
    fs.copyFileSync(DB_FILE, dest);
    res.json({ ok: true, path: dest });
  } catch(e){
    console.error('Backup failed', e);
    res.status(500).json({ error: 'backup failed' });
  }
});

const PORT = process.env.PORT || 4000;

// Start HTTP or HTTPS server depending on environment variables
if (process.env.USE_HTTPS === '1' && process.env.SSL_CERT_PATH && process.env.SSL_KEY_PATH && fs.existsSync(process.env.SSL_CERT_PATH) && fs.existsSync(process.env.SSL_KEY_PATH)) {
  try {
    const https = require('https');
    const cert = fs.readFileSync(process.env.SSL_CERT_PATH);
    const key = fs.readFileSync(process.env.SSL_KEY_PATH);
    https.createServer({ key, cert }, app).listen(PORT, () => console.log('Backend running (https) on', PORT));
  } catch (e) {
    console.error('Failed to start HTTPS server, falling back to HTTP', e);
    app.listen(PORT, () => console.log('Backend running on', PORT));
  }
} else {
  app.listen(PORT, () => console.log('Backend running on', PORT));
}
