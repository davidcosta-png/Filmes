const { Pool } = require('pg');
const bcrypt = require('bcrypt');

let pool;

async function init(){
  const conn = process.env.POSTGRES_URL || process.env.DATABASE_URL;
  if(!conn) throw new Error('POSTGRES_URL or DATABASE_URL not set');
  pool = new Pool({ connectionString: conn });
  // create table if not exists
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      passwordHash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      paused BOOLEAN NOT NULL DEFAULT false,
      refreshToken TEXT,
      refreshTokenExpiry BIGINT
    );
  `);
}

async function findUserByUsername(username){
  const res = await pool.query('SELECT * FROM users WHERE username = $1 LIMIT 1', [username]);
  return res.rows[0];
}
async function findUserByRefreshToken(token){
  if(!token) return null;
  const res = await pool.query('SELECT * FROM users WHERE refreshToken = $1 LIMIT 1', [token]);
  return res.rows[0];
}
async function saveRefreshTokenForUser(username, refreshToken, expiry){
  await pool.query('UPDATE users SET refreshToken = $1, refreshTokenExpiry = $2 WHERE username = $3', [refreshToken, expiry, username]);
}
async function revokeRefreshToken(refreshToken){
  await pool.query('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE refreshToken = $1', [refreshToken]);
}
async function createUser(username, passwordHash, role){
  await pool.query('INSERT INTO users (username, passwordHash, role, paused) VALUES ($1, $2, $3, false)', [username, passwordHash, role || 'user']);
}
async function listUsers(){
  const res = await pool.query('SELECT username, role, paused FROM users');
  return res.rows;
}
async function updatePaused(username, paused){
  await pool.query('UPDATE users SET paused = $1 WHERE username = $2', [paused ? true : false, username]);
  if(paused){ await pool.query('UPDATE users SET refreshToken = NULL, refreshTokenExpiry = NULL WHERE username = $1', [username]); }
}
async function deleteUser(username){
  const res = await pool.query('DELETE FROM users WHERE username = $1', [username]);
  return res;
}
async function ensureAdmin(adminUser, adminPass){
  const res = await pool.query('SELECT 1 FROM users WHERE role = $1 LIMIT 1', ['admin']);
  if(res.rowCount === 0){
    const user = adminUser || process.env.ADMIN_USER || 'Davi';
    const pass = adminPass || process.env.ADMIN_PASS || '1234';
    const h = await bcrypt.hash(pass, 10);
    await pool.query('INSERT INTO users (username, passwordHash, role, paused) VALUES ($1, $2, $3, false)', [user, h, 'admin']);
    console.log('Admin user created:', user);
  }
}
async function backupToJson(){
  const res = await pool.query('SELECT username, role, paused, refreshToken, refreshTokenExpiry FROM users');
  return JSON.stringify({ generatedAt: new Date().toISOString(), users: res.rows }, null, 2);
}

module.exports = { init, findUserByUsername, findUserByRefreshToken, saveRefreshTokenForUser, revokeRefreshToken, createUser, listUsers, updatePaused, deleteUser, ensureAdmin, backupToJson };
