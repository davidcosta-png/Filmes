const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const db = require('./db');

const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const JWT_SECRET = process.env.JWT_SECRET || 'replace_with_secure_secret_in_production';
const app = express();
app.use(cors());
app.use(bodyParser.json());

// health
app.get('/auth/health', (req, res) => res.json({ ok: true }));

// utility: encrypt a buffer with AES-256-GCM using BACKUP_KEY (base64)
function encryptBuffer(buffer){
  const keyEnv = process.env.BACKUP_KEY;
  if(!keyEnv) throw new Error('BACKUP_KEY not set');
  // BACKUP_KEY is base64 or hex; try base64 then hex
  let key;
  try { key = Buffer.from(keyEnv, 'base64'); if(key.length !== 32) throw new Error('len'); } catch(e){ key = Buffer.from(keyEnv, 'hex'); }
  if(key.length !== 32) throw new Error('BACKUP_KEY must be 32 bytes (base64 or hex)');
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(buffer), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]); // store iv(12) + tag(16) + ciphertext
}

async function uploadToS3(buffer, keyName){
  const bucket = process.env.BACKUP_S3_BUCKET;
  if(!bucket) throw new Error('BACKUP_S3_BUCKET not set');
  const region = process.env.AWS_REGION || 'us-east-1';
  const client = new S3Client({ region });
  const cmd = new PutObjectCommand({ Bucket: bucket, Key: keyName, Body: buffer });
  await client.send(cmd);
}

// Middleware: verify JWT and attach user; also block paused users
async function verifyToken(req, res, next){
  const auth = req.headers['authorization'];
  if(!auth) return res.status(401).json({ error: 'No token provided' });
  const parts = auth.split(' ');
  if(parts.length !== 2) return res.status(401).json({ error: 'Invalid auth header' });
  const token = parts[1];
  try{
    const decoded = jwt.verify(token, JWT_SECRET);
    // check paused status
    const u = await db.findUserByUsername(decoded.username);
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
  const user = await db.findUserByUsername(username);
  if(!user) return res.status(401).json({ error: 'Invalid credentials' });
  const match = await bcrypt.compare(password, user.passwordHash);
  if(!match) return res.status(401).json({ error: 'Invalid credentials' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  const refreshToken = crypto.randomBytes(32).toString('hex');
  const expiry = Date.now() + 7 * 24 * 60 * 60 * 1000; // 7 days
  await db.saveRefreshTokenForUser(user.username, refreshToken, expiry);
  res.json({ token, refreshToken });
});

app.get('/auth/me', verifyToken, (req, res) => {
  const u = req.user || {};
  res.json({ username: u.username, role: u.role });
});

app.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  const user = await db.findUserByRefreshToken(refreshToken);
  if(!user) return res.status(401).json({ error: 'Invalid refresh token' });
  if(!user.refreshTokenExpiry || Date.now() > user.refreshTokenExpiry) return res.status(401).json({ error: 'Refresh token expired' });
  if (user.paused) return res.status(403).json({ error: 'User is paused' });
  // rotate refresh token
  const newRefresh = crypto.randomBytes(32).toString('hex');
  const newExpiry = Date.now() + 7 * 24 * 60 * 60 * 1000;
  await db.saveRefreshTokenForUser(user.username, newRefresh, newExpiry);
  const token = jwt.sign({ username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
  res.json({ token, refreshToken: newRefresh });
});

app.post('/auth/logout', async (req, res) => {
  const { refreshToken } = req.body;
  if(!refreshToken) return res.status(400).json({ error: 'refreshToken required' });
  await db.revokeRefreshToken(refreshToken);
  res.json({ ok: true });
});

// Protected user management routes (admin only)
app.get('/users', verifyToken, adminOnly, async (req, res) => {
  const rows = await db.listUsers();
  res.json(rows.map(r => ({ username: r.username, role: r.role, paused: !!r.paused })));
});

app.post('/users', verifyToken, adminOnly, async (req, res) => {
  const { username, password, role } = req.body;
  if(!username || !password) return res.status(400).json({ error: 'username and password required' });
  const exists = await db.findUserByUsername(username);
  if(exists) return res.status(400).json({ error: 'already exists' });
  const hash = await bcrypt.hash(password, 10);
  await db.createUser(username, hash, role || 'user');
  res.status(201).json({ ok: true });
});

app.post('/users/:username/pause', verifyToken, adminOnly, async (req, res) => {
  const { username } = req.params;
  const u = await db.findUserByUsername(username);
  if(!u) return res.status(404).json({ error: 'not found' });
  const paused = !!req.body.paused;
  await db.updatePaused(username, paused);
  res.json({ ok: true });
});

app.delete('/users/:username', verifyToken, adminOnly, async (req, res) => {
  const { username } = req.params;
  const info = await db.deleteUser(username);
  res.json({ ok: true });
});

// Admin seed
(async function(){
  await db.ensureInitialized();
  await db.ensureAdmin(process.env.ADMIN_USER, process.env.ADMIN_PASS);
})();

// Backup endpoint: create JSON backup, encrypt with BACKUP_KEY and either upload to S3 or save locally
app.post('/admin/backup', verifyToken, adminOnly, async (req, res) => {
  try{
    const json = await db.backupToJson();
    const buffer = Buffer.from(json, 'utf8');
    // encrypt if BACKUP_KEY provided
    if(process.env.BACKUP_KEY){
      const enc = encryptBuffer(buffer);
      // if S3 bucket configured, upload
      if(process.env.BACKUP_S3_BUCKET){
        const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
        const keyName = `${process.env.BACKUP_S3_PREFIX || ''}users-${timestamp}.enc`;
        await uploadToS3(enc, keyName);
        return res.json({ ok: true, uploaded: true, key: keyName });
      } else {
        // save locally
        const backupsDir = path.join(DATA_DIR, 'backups');
        if(!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir, { recursive: true });
        const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
        const dest = path.join(backupsDir, `users-${timestamp}.enc`);
        fs.writeFileSync(dest, enc);
        return res.json({ ok: true, path: dest });
      }
    } else {
      // no encryption key: save plain JSON locally
      const backupsDir = path.join(DATA_DIR, 'backups');
      if(!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir, { recursive: true });
      const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
      const dest = path.join(backupsDir, `users-${timestamp}.json`);
      fs.writeFileSync(dest, json);
      return res.json({ ok: true, path: dest });
    }
  } catch(e){
    console.error('Backup failed', e);
    res.status(500).json({ error: 'backup failed', details: e.message });
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
