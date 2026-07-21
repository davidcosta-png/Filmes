const fs = require('fs');
const path = require('path');
const db = require('./db');
const crypto = require('crypto');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

function encryptBuffer(buffer){
  const keyEnv = process.env.BACKUP_KEY;
  if(!keyEnv) throw new Error('BACKUP_KEY not set');
  let key;
  try { key = Buffer.from(keyEnv, 'base64'); if(key.length !== 32) throw new Error('len'); } catch(e){ key = Buffer.from(keyEnv, 'hex'); }
  if(key.length !== 32) throw new Error('BACKUP_KEY must be 32 bytes (base64 or hex)');
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(buffer), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]);
}

async function uploadToS3(buffer, keyName){
  const bucket = process.env.BACKUP_S3_BUCKET;
  if(!bucket) throw new Error('BACKUP_S3_BUCKET not set');
  const region = process.env.AWS_REGION || 'us-east-1';
  const client = new S3Client({ region });
  const cmd = new PutObjectCommand({ Bucket: bucket, Key: keyName, Body: buffer });
  await client.send(cmd);
}

(async function(){
  try{
    await db.ensureInitialized();
    const json = await db.backupToJson();
    const buffer = Buffer.from(json, 'utf8');
    if(process.env.BACKUP_KEY){
      const enc = encryptBuffer(buffer);
      if(process.env.BACKUP_S3_BUCKET){
        const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
        const keyName = `${process.env.BACKUP_S3_PREFIX || ''}users-${timestamp}.enc`;
        await uploadToS3(enc, keyName);
        console.log('Uploaded to S3 as', keyName);
      } else {
        const backupsDir = path.join(__dirname, 'data', 'backups');
        if(!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir, { recursive: true });
        const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
        const dest = path.join(backupsDir, `users-${timestamp}.enc`);
        fs.writeFileSync(dest, enc);
        console.log('Saved encrypted backup to', dest);
      }
    } else {
      const backupsDir = path.join(__dirname, 'data', 'backups');
      if(!fs.existsSync(backupsDir)) fs.mkdirSync(backupsDir, { recursive: true });
      const timestamp = new Date().toISOString().replace(/[:.]/g,'-');
      const dest = path.join(backupsDir, `users-${timestamp}.json`);
      fs.writeFileSync(dest, json);
      console.log('Saved JSON backup to', dest);
    }
  } catch(e){
    console.error('Backup failed', e);
    process.exit(1);
  }
})();