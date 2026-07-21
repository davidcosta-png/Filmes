const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const USERS_FILE = __dirname + '/users.json';
const JWT_SECRET = process.env.JWT_SECRET || 'replace_with_secure_secret_in_production'; // change in production and set JWT_SECRET env var in production

const app = express();
app.use(cors());
app.use(bodyParser.json());

// simple health endpoint used by CI to detect backend readiness
app.get('/auth/health', (req, res) => res.json({ ok: true }));

function loadUsers(){
  if(!fs.existsSync(USERS_FILE)) return [];
  try { return JSON.parse(fs.readFileSync(USERS_FILE)); } catch(e) { console.error('Failed to parse users.json', e); return []; }
}
function saveUsers(users){
  fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
}

function findUserByUsername(username){
  const users = loadUsers();
  return users.find(u => u.username === username);
}
function findUserByRefreshToken(token){
  const users = loadUsers();
  return users.find(u => u.refreshToken === token);
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
  const users = loadUsers();
  const user = users.find(u => u.username === username);
  if(!user) return res.status(401).json({ error: 'Invalid credentials' });
  const match = await bcrypt.compare(password, user.passwordHash);
  if(!match) return res.status(401).json({ error: 'Invalid credentials' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  // generate refresh token
  const refreshToken = crypto.randomBytes(32).toString('hex');
  const expiry = Date.now() + 7 * 24 * 60 * 60 * 1000; // 7 days
  user.refreshToken = refreshToken;
  user.refreshTokenExpiry = expiry;
  saveUsers(users);
  res.json({ token, refreshToken });
});

// token introspection endpoint
app.get('/auth/me', verifyToken, (req, res) => {
  const u = req.user || {};
  res.json({ username: u.username, role: u.role });
});

// refresh token endpoint
app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  const user = findUserByRefreshToken(refreshToken);
  if(!user) return res.status(401).json({ error: 'Invalid refresh token' });
  if(!user.refreshTokenExpiry || Date.now() > user.refreshTokenExpiry) return res.status(401).json({ error: 'Refresh token expired' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  // rotate refresh token
  const newRefresh = crypto.randomBytes(32).toString('hex');
  // persist the rotated refresh token into the stored users list
  const users = loadUsers();
  const idx = users.findIndex(u => u.username === user.username);
  if (idx !== -1) {
    users[idx].refreshToken = newRefresh;
    users[idx].refreshTokenExpiry = Date.now() + 7 * 24 * 60 * 60 * 1000;
    saveUsers(users);
  }
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  res.json({ token, refreshToken: newRefresh });
});

// logout / revoke refresh token
app.post('/auth/logout', (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  const users = loadUsers();
  const user = users.find(u => u.refreshToken === refreshToken);
  if(user){
    delete user.refreshToken;
    delete user.refreshTokenExpiry;
    saveUsers(users);
  }
  res.json({ ok: true });
});

// Protected user management routes (admin only)
app.get('/users', verifyToken, adminOnly, (req, res) => {
  const users = loadUsers().map(u => ({ username: u.username, role: u.role, paused: !!u.paused }));
  res.json(users);
});

app.post('/users', verifyToken, adminOnly, async (req, res) => {
  const { username, password, role } = req.body;
  if(!username || !password) return res.status(400).json({ error: 'username and password required' });
  const users = loadUsers();
  if(users.find(u => u.username === username)) return res.status(400).json({ error: 'already exists' });
  const hash = await bcrypt.hash(password, 10);
  users.push({ username, passwordHash: hash, role: role || 'user', paused: false });
  saveUsers(users);
  res.status(201).json({ ok: true });
});

app.post('/users/:username/pause', verifyToken, adminOnly, (req, res) => {
  const { username } = req.params;
  const users = loadUsers();
  const u = users.find(x => x.username === username);
  if(!u) return res.status(404).json({ error: 'not found' });
  u.paused = !!req.body.paused;
  // revoke refresh token to force logout
  if(u.paused){ delete u.refreshToken; delete u.refreshTokenExpiry; }
  saveUsers(users);
  res.json({ ok: true });
});

app.delete('/users/:username', verifyToken, adminOnly, (req, res) => {
  const { username } = req.params;
  let users = loadUsers();
  const idx = users.findIndex(x => x.username === username);
  if(idx === -1) return res.status(404).json({ error: 'not found' });
  users.splice(idx, 1);
  saveUsers(users);
  res.json({ ok: true });
});
// create an initial admin user if none exists
(function ensureAdmin(){
  const users = loadUsers();
  if(!users.find(u => u.role === 'admin')){
    const bcrypt = require('bcrypt');
    const defaultAdminUser = 'Davi';
    const defaultAdminPass = '1234';
    bcrypt.hash(defaultAdminPass, 10).then(h => {
      users.push({ username: defaultAdminUser, passwordHash: h, role: 'admin', paused: false });
      saveUsers(users);
      console.log(`Admin user created: ${defaultAdminUser} / ${defaultAdminPass} (change password)`);
    }).catch(err => console.error('Error creating default admin', err));
  }
})();

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
