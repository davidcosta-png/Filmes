const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const bcrypt = require('bcrypt');

const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
const DB_FILE = path.join(DATA_DIR, 'users.db');
const db = new Database(DB_FILE);

function init() {
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
}

function findUserByUsername(username){
  return db.prepare('SELECT * FROM users WHERE username = ?').get(username);
}
function findUserByRefreshToken(token){
  if(!token) return null;
  return db.prepare('SELECT * FROM users WHERE refreshToken = ?').get(token);
}
function saveRefreshTokenForUser(username, refreshToken, expiry){
  db.prepare('UPDATE users SET refreshToken = ?, refreshTokenExpiry = ? WHERE username = ?').run(refreshToken, expiry, username);
}
function revokeRefreshToken(refreshToken){
  db.prepare('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE refreshToken = ?').run(refreshToken);
}
function createUser(username, passwordHash, role){
  db.prepare('INSERT INTO users (username, passwordHash, role, paused) VALUES (?, ?, ?, 0)').run(username, passwordHash, role || 'user');
}
function listUsers(){
  return db.prepare('SELECT username, role, paused FROM users').all();
}
function updatePaused(username, paused){
  db.prepare('UPDATE users SET paused = ? WHERE username = ?').run(paused ? 1 : 0, username);
  if(paused){ db.prepare('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE username = ?').run(username); }
}
function deleteUser(username){
  return db.prepare('DELETE FROM users WHERE username = ?').run(username);
}
async function ensureAdmin(adminUser, adminPass){
  const adminExists = db.prepare('SELECT 1 FROM users WHERE role = "admin" LIMIT 1').get();
  if(!adminExists){
    const pass = adminPass || process.env.ADMIN_PASS || '1234';
    const user = adminUser || process.env.ADMIN_USER || 'Davi';
    const h = await bcrypt.hash(pass, 10);
    db.prepare('INSERT INTO users (username, passwordHash, role, paused) VALUES (?, ?, "admin", 0)').run(user, h);
    console.log(`Admin user created: ${user}`);
  }
}
function backupToJson(){
  const rows = db.prepare('SELECT username, role, paused, refreshToken, refreshTokenExpiry FROM users').all();
  return JSON.stringify({ generatedAt: new Date().toISOString(), users: rows }, null, 2);
}

module.exports = {
  init,
  findUserByUsername,
  findUserByRefreshToken,
  saveRefreshTokenForUser,
  revokeRefreshToken,
  createUser,
  listUsers,
  updatePaused,
  deleteUser,
  ensureAdmin,
  backupToJson
};