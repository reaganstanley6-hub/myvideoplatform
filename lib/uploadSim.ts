type UploadRecord = {
  id: string;
  file: string;
  progress: number; // 0-100
  status: 'pending' | 'processing' | 'done' | 'error';
};

const uploads = new Map<string, UploadRecord>();

export function createUpload(id: string, file: string) {
  const rec: UploadRecord = { id, file, progress: 0, status: 'pending' };
  uploads.set(id, rec);
  return rec;
}

export function getUpload(id: string) {
  return uploads.get(id) || null;
}

export function setProgress(id: string, p: number) {
  const rec = uploads.get(id);
  if (!rec) return;
  const val = Math.max(0, Math.min(100, Math.floor(p)));
  rec.progress = val;
  // try to persist to DB if available
  try {
    const db = require('./db');
    if (db && typeof db.updateProgress === 'function') {
      db.updateProgress(id, val);
    }
  } catch (e) {
    // ignore
  }
}

export function setStatus(id: string, status: UploadRecord['status']) {
  const rec = uploads.get(id);
  if (!rec) return;
  rec.status = status;
  try {
    const db = require('./db');
    if (db && typeof db.updateStatus === 'function') {
      db.updateStatus(id, status);
    }
  } catch (e) {
    // ignore
  }
}

export function startProcessing(id: string) {
  const rec = uploads.get(id);
  if (!rec) return;
  if (rec.status !== 'pending') return;

  rec.status = 'processing';
  rec.progress = 0;

  const interval = setInterval(() => {
    rec.progress += Math.floor(Math.random() * 15) + 5; // random progress jumps
    if (rec.progress >= 100) {
      rec.progress = 100;
      rec.status = 'done';
      clearInterval(interval);
    }
  }, 600);

  return rec;
}
