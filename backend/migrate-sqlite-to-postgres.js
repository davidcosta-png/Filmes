const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const { Client } = require('pg');

async function main(){
  const dataDir = path.join(__dirname, 'data');
  const sqliteFile = path.join(dataDir, 'users.db');
  if(!fs.existsSync(sqliteFile)){
    console.error('SQLite DB not found at', sqliteFile);
    process.exit(1);
  }

  const pgUrl = process.env.POSTGRES_URL || process.env.DATABASE_URL;
  if(!pgUrl){
    console.error('POSTGRES_URL / DATABASE_URL not set. Aborting.');
    process.exit(1);
  }

  const sqlite = new Database(sqliteFile, { readonly: true });
  const rows = sqlite.prepare('SELECT username, passwordHash, role, paused, refreshToken, refreshTokenExpiry FROM users').all();
  console.log('Found', rows.length, 'users in SQLite');

  const client = new Client({ connectionString: pgUrl });
  await client.connect();

  await client.query(`
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

  let inserted = 0;
  for(const r of rows){
    try{
      // upsert: insert if not exists
      await client.query(`
        INSERT INTO users (username, passwordHash, role, paused, refreshToken, refreshTokenExpiry)
        VALUES ($1,$2,$3,$4,$5,$6)
        ON CONFLICT (username) DO UPDATE SET
          passwordHash = EXCLUDED.passwordHash,
          role = EXCLUDED.role,
          paused = EXCLUDED.paused,
          refreshToken = EXCLUDED.refreshToken,
          refreshTokenExpiry = EXCLUDED.refreshTokenExpiry;
      `, [r.username, r.passwordHash, r.role || 'user', r.paused ? true : false, r.refreshToken || null, r.refreshTokenExpiry || null]);
      inserted++;
    }catch(e){
      console.error('Failed to upsert user', r.username, e.message);
    }
  }

  console.log('Upserted', inserted, 'users into Postgres');
  await client.end();
  sqlite.close();
}

main().catch(e => { console.error(e); process.exit(1); });
