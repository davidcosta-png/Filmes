let impl = null;

async function ensureInitialized(){
  if (impl) return;
  // select implementation
  if (process.env.POSTGRES_URL || process.env.DATABASE_URL || process.env.PGHOST) {
    impl = require('./db_pg');
  } else {
    impl = require('./db_sqlite');
  }
  if (impl && impl.init) await impl.init();
}

module.exports = {
  ensureInitialized,
  findUserByUsername: async (...args) => { await ensureInitialized(); return impl.findUserByUsername(...args); },
  findUserByRefreshToken: async (...args) => { await ensureInitialized(); return impl.findUserByRefreshToken(...args); },
  saveRefreshTokenForUser: async (...args) => { await ensureInitialized(); return impl.saveRefreshTokenForUser(...args); },
  revokeRefreshToken: async (...args) => { await ensureInitialized(); return impl.revokeRefreshToken(...args); },
  createUser: async (...args) => { await ensureInitialized(); return impl.createUser(...args); },
  listUsers: async (...args) => { await ensureInitialized(); return impl.listUsers(...args); },
  updatePaused: async (...args) => { await ensureInitialized(); return impl.updatePaused(...args); },
  deleteUser: async (...args) => { await ensureInitialized(); return impl.deleteUser(...args); },
  ensureAdmin: async (...args) => { await ensureInitialized(); return impl.ensureAdmin(...args); },
  backupToJson: async (...args) => { await ensureInitialized(); return impl.backupToJson(...args); }
};