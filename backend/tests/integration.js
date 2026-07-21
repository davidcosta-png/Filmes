const axios = require('axios');

const BASE = process.env.BASE_URL || 'http://localhost:4000';

function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }

async function tryLogin(retries = 60){ // retry for up to ~30s
  for(let i=0;i<retries;i++){
    try{
      const res = await axios.post(`${BASE}/auth/login`, { username: 'Davi', password: '1234' }, { timeout: 3000 });
      return res.data;
    }catch(e){
      // wait and retry
      await sleep(500);
    }
  }
  throw new Error('Login failed after retries');
}

(async function(){
  try{
    console.log('Attempting login (may retry while server creates admin)');
    const login = await tryLogin();
    if(!login || !login.token || !login.refreshToken) throw new Error('Login did not return token/refreshToken');
    console.log('Login OK');

    const token = login.token;
    const refreshToken = login.refreshToken;

    // me
    const me = await axios.get(`${BASE}/auth/me`, { headers: { Authorization: `Bearer ${token}` } });
    if(!me.data || !me.data.username) throw new Error('Invalid /auth/me response');
    console.log('/auth/me OK');

    // refresh
    const r2 = await axios.post(`${BASE}/auth/refresh`, { refreshToken }, { timeout: 5000 });
    if(!r2.data || !r2.data.refreshToken) throw new Error('Refresh failed');
    if(r2.data.refreshToken === refreshToken) throw new Error('Refresh token was not rotated');
    console.log('/auth/refresh OK');

    // logout
    const r3 = await axios.post(`${BASE}/auth/logout`, { refreshToken: r2.data.refreshToken });
    if(!r3.data || r3.data.ok !== true) throw new Error('Logout failed');
    console.log('/auth/logout OK');

    console.log('INTEGRATION TESTS PASSED');
    process.exit(0);
  }catch(err){
    console.error('INTEGRATION TESTS FAILED', err && err.response ? err.response.data : err.message);
    process.exit(1);
  }
})();
