import path from 'path';
import fs from 'fs';

let useSqlite = false;
let db: any = null;

try {
  // lazy require so project can work without sqlite if not installed
  const Database = require('better-sqlite3');
  const dir = path.join(process.cwd(), '.data');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const dbPath = path.join(dir, 'uploads.db');
  db = new Database(dbPath);
  useSqlite = true;

  db.exec(`
    CREATE TABLE IF NOT EXISTS uploads (
      id TEXT PRIMARY KEY,
      file TEXT,
      status TEXT,
      progress INTEGER,
      out_file TEXT,
      hls_dir TEXT,
      error TEXT,
      created_at INTEGER,
      updated_at INTEGER
    );

    CREATE TABLE IF NOT EXISTS jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      upload_id TEXT,
      status TEXT,
      created_at INTEGER
    );
  `);
} catch (e) {
  // sqlite not available — fall back to in-memory storage
  useSqlite = false;
}

const memoryUploads: Map<string, any> = new Map();
const memoryJobs: Array<any> = [];

function now() { return Date.now(); }

export function createUpload(id: string, file: string) {
  if (useSqlite) {
    const stmt = db.prepare(`INSERT OR REPLACE INTO uploads (id,file,status,progress,created_at,updated_at) VALUES (?,?,?,?,?,?)`);
    stmt.run(id, file, 'pending', 0, now(), now());
    return { id, file, status: 'pending', progress: 0 };
  } else {
    const rec = { id, file, status: 'pending', progress: 0, created_at: now(), updated_at: now() };
    memoryUploads.set(id, rec);
    // enqueue job
    memoryJobs.push({ upload_id: id, status: 'pending', created_at: now() });
    return rec;
  }
}

export function updateProgress(id: string, progress: number) {
  if (useSqlite) {
    const stmt = db.prepare('UPDATE uploads SET progress = ?, updated_at = ? WHERE id = ?');
    stmt.run(Math.max(0, Math.min(100, Math.floor(progress))), now(), id);
  } else {
    const rec = memoryUploads.get(id);
    if (rec) { rec.progress = Math.max(0, Math.min(100, Math.floor(progress))); rec.updated_at = now(); }
  }
}

export function updateStatus(id: string, status: string) {
  if (useSqlite) {
    const stmt = db.prepare('UPDATE uploads SET status = ?, updated_at = ? WHERE id = ?');
    stmt.run(status, now(), id);
  } else {
    const rec = memoryUploads.get(id);
    if (rec) { rec.status = status; rec.updated_at = now(); }
  }
}

export function setOutputFiles(id: string, out_file: string | null, hls_dir: string | null) {
  if (useSqlite) {
    const stmt = db.prepare('UPDATE uploads SET out_file = ?, hls_dir = ?, updated_at = ? WHERE id = ?');
    stmt.run(out_file, hls_dir, now(), id);
  } else {
    const rec = memoryUploads.get(id);
    if (rec) { rec.out_file = out_file; rec.hls_dir = hls_dir; rec.updated_at = now(); }
  }
}

export function getUpload(id: string) {
  if (useSqlite) {
    const stmt = db.prepare('SELECT * FROM uploads WHERE id = ?');
    return stmt.get(id) || null;
  } else {
    return memoryUploads.get(id) || null;
  }
}

export function enqueueJob(uploadId: string) {
  if (useSqlite) {
    const stmt = db.prepare('INSERT INTO jobs (upload_id,status,created_at) VALUES (?,?,?)');
    stmt.run(uploadId, 'pending', now());
  } else {
    memoryJobs.push({ upload_id: uploadId, status: 'pending', created_at: now() });
  }
}

export function fetchNextJob() {
  if (useSqlite) {
    // fetch a pending job
    const row = db.prepare('SELECT * FROM jobs WHERE status = ? ORDER BY created_at ASC LIMIT 1').get('pending');
    if (!row) return null;
    db.prepare('UPDATE jobs SET status = ? WHERE id = ?').run('processing', row.id);
    return row;
  } else {
    for (let i = 0; i < memoryJobs.length; i++) {
      const j = memoryJobs[i];
      if (j.status === 'pending') { j.status = 'processing'; return j; }
    }
    return null;
  }
}

export function finishJob(jobId: number) {
  if (useSqlite) {
    db.prepare('UPDATE jobs SET status = ? WHERE id = ?').run('done', jobId);
  } else {
    const j = memoryJobs.find(x => x.id === jobId);
    if (j) j.status = 'done';
  }
}

export function isSqliteAvailable() { return useSqlite; }
