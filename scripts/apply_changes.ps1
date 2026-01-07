<#
apply_changes.ps1

This script will create/overwrite project files with the versions included in this script.
It makes a backup of any existing files it will overwrite to `.backup_changes_<timestamp>/`.

It will not attempt to commit by default. Use `git_commit_when_available.ps1` to commit or pass the `-Commit` flag.

Usage:
  powershell -ExecutionPolicy Bypass -File scripts\apply_changes.ps1 [-Commit]

#>
param(
  [switch]$Commit
)

$base = Get-Location
$backupDir = Join-Path $base (".backup_changes_" + (Get-Date -Format yyyyMMddHHmmss))
New-Item -Path $backupDir -ItemType Directory | Out-Null

function Backup-File($path) {
  if (Test-Path $path) {
    $dest = Join-Path $backupDir ($path -replace "[\\/:]","_")
    New-Item -Path (Split-Path $dest -Parent) -ItemType Directory -Force | Out-Null
    Copy-Item -Path $path -Destination $dest -Recurse -Force
    Write-Host "Backed up $path -> $dest"
  }
}

function Write-TextFile($path, $content) {
  $dir = Split-Path $path -Parent
  if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
  Backup-File $path
  $content | Out-File -FilePath $path -Encoding utf8 -Force
  Write-Host "Wrote $path"
}

function Write-BinaryFileFromBase64($path, $b64) {
  $dir = Split-Path $path -Parent
  if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
  Backup-File $path
  [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($b64))
  Write-Host "Wrote binary $path"
}

# -------- BEGIN FILES --------

# app/components/Nav.tsx
$path = "app/components/Nav.tsx"
$content = @'
"use client";

import Link from "next/link";

export default function Nav() {
  return (
    <nav className="flex items-center justify-between px-6 py-4 bg-gray-900 text-white">
      <div className="text-xl font-bold">My Video Platform</div>
      <ul className="flex space-x-4 text-sm">
        <li>
          <Link href="/" className="hover:underline">
            Home
          </Link>
        </li>
        <li>
          <Link href="/upload" className="hover:underline">
            Upload
          </Link>
        </li>
      </ul>
    </nav>
  );
}
'@
Write-TextFile $path $content

# tailwind.config.js
$path = "tailwind.config.js"
$content = @'
/** @type {import(''tailwindcss'').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}'
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
'@
Write-TextFile $path $content

# app/globals.css
$path = "app/globals.css"
$content = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --background: #ffffff;
  --foreground: #171717;
}

@media (prefers-color-scheme: dark) {
  :root {
    --background: #0a0a0a;
    --foreground: #ededed;
  }
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: var(--font-geist-sans, Arial, Helvetica, sans-serif);
}
'@
Write-TextFile $path $content

# app/page.tsx
$path = "app/page.tsx"
$content = @'
import fs from "fs";
import path from "path";

export default function Home() {
  const videoDir = path.join(process.cwd(), "public/videos");
  let files: string[] = [];

  try {
    files = fs.readdirSync(videoDir);
  } catch (err) {
    console.error("Error reading videos folder:", err);
  }

  return (
    <main className="min-h-screen bg-black text-white">
      <section className="flex flex-col items-center justify-center mt-20">
        <h2 className="text-4xl font-bold mb-4">Welcome, Reagan</h2>
        <p className="text-lg opacity-80">Your video empire starts here.</p>
      </section>

      <section className="px-6 py-10">
        <h3 className="text-2xl font-semibold mb-6">Featured Videos</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
          {files.map((file, index) => (
            <div key={index} className="bg-gray-800 p-4 rounded-lg">
              <video
                src={`/videos/${file}`}
                controls
                className="w-full h-40 rounded mb-3 object-cover"
              />
              <h4 className="text-lg font-bold">{file}</h4>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
'@
Write-TextFile $path $content

# app/upload/page.tsx
$path = "app/upload/page.tsx"
$content = @'
"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";

export default function UploadPage() {
  const [file, setFile] = useState<File | null>(null);
  const [msg, setMsg] = useState("");
  const [uploading, setUploading] = useState(false);
  const router = useRouter();
  const [preview, setPreview] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      if (preview) {
        URL.revokeObjectURL(preview);
      }
    };
  }, [preview]);

  async function upload() {
    if (!file) {
      setMsg("Please select a video first.");
      return;
    }

    setMsg("Uploading...");
    setUploading(true);

    // use XHR to get upload progress events
    const xhr = new XMLHttpRequest();
    const form = new FormData();
    form.append("file", file);

    xhr.open('POST', '/api/upload');

    xhr.upload.onprogress = (ev) => {
      if (ev.lengthComputable) {
        const percent = Math.round((ev.loaded / ev.total) * 100);
        setMsg(`Uploading... ${percent}%`);
      }
    };

    xhr.onload = async () => {
      setUploading(false);
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const data = JSON.parse(xhr.responseText);
          if (data.error) {
            setMsg('Upload failed: ' + data.error);
          } else {
            setMsg('Upload complete. Processing...');
            setFile(null);

            const id = data.id;
            if (id) {
              // listen for server processing via SSE
              const es = new EventSource(`/api/process/${id}`);
              es.addEventListener('progress', (ev: any) => {
                try {
                  const d = JSON.parse(ev.data);
                  setMsg(`Processing: ${d.progress}%`);
                } catch (e) {}
              });
              es.addEventListener('done', (ev: any) => {
                try {
                  const d = JSON.parse(ev.data);
                  setMsg(`Finished processing: ${d.file}`);
                  es.close();
                  setTimeout(() => router.push('/'), 1200);
                } catch (e) {}
              });

              es.addEventListener('notfound', () => {
                setMsg('Processing info not found.');
                es.close();
                setTimeout(() => router.push('/'), 1200);
              });
            } else {
              setTimeout(() => router.push('/'), 800);
            }
          }
        } catch (e) {
          setMsg('Upload failed: invalid server response');
        }
      } else {
        setMsg('Upload failed: ' + xhr.statusText);
      }
    };

    xhr.onerror = () => {
      setUploading(false);
      setMsg('Upload failed: network error');
    };

    xhr.send(form);
  }

  return (
    <main className="min-h-screen bg-black text-white p-6">
      <h1 className="text-3xl font-bold mb-6">Upload Video</h1>

      <input
        type="file"
        accept="video/*"
        onChange={(e) => {
          const selected = e.target.files?.[0];
          setFile(selected || null);
          setMsg(""); // Clear message when new file is selected
          // generate preview
          if (selected) {
            const url = URL.createObjectURL(selected);
            setPreview(url);
          } else {
            if (preview) {
              URL.revokeObjectURL(preview);
              setPreview(null);
            }
          }
        }}
        className="mb-4 block"
      />

      {preview && (
        <div className="mb-4">
          <h4 className="mb-2">Preview</h4>
          <video src={preview} controls className="w-full h-48 rounded object-cover" />
        </div>
      )}

      <button
        onClick={upload}
        disabled={uploading}
        className={`px-4 py-2 bg-blue-600 rounded hover:bg-blue-500 ${uploading ? 'opacity-60 cursor-wait' : ''}`}
      >
        {uploading ? 'Uploading…' : 'Upload'}
      </button>

      <p className="mt-4">{msg}</p>
    </main>
  );
}
'@
Write-TextFile $path $content

# app/api/upload/route.ts
$path = "app/api/upload/route.ts"
$content = @'
import { NextResponse } from "next/server";
import { writeFile, mkdir } from "fs/promises";
import path from "path";

const MAX_BYTES = 500 * 1024 * 1024; // 500MB
const ALLOWED = [
  ".mp4",
  ".webm",
  ".ogg",
  ".mov",
  ".mkv",
];

export async function POST(req: Request) {
  try {
    const form = await req.formData();
    const file = form.get("file") as File | null;

    if (!file) return NextResponse.json({ error: "No file uploaded" }, { status: 400 });

    const name = file.name || `upload-${Date.now()}`;
    const ext = path.extname(name).toLowerCase();

    if (!ALLOWED.includes(ext)) {
      return NextResponse.json({ error: `Unsupported file type: ${ext}` }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    if (buffer.length > MAX_BYTES) {
      return NextResponse.json({ error: `File too large (max ${MAX_BYTES} bytes)` }, { status: 413 });
    }

    const dir = path.join(process.cwd(), "public/videos");
    await mkdir(dir, { recursive: true });

    const filePath = path.join(dir, name);
    await writeFile(filePath, buffer);

    // record upload in DB (if available) and enqueue a job
    let db = null;
    try { db = await import('../../../lib/db'); } catch (e) { db = null; }

    const id = `${Date.now()}-${Math.random().toString(36).slice(2,8)}`;

    if (db && typeof db.createUpload === 'function') {
      db.createUpload(id, name);
      // enqueue in DB-backed jobs
      db.enqueueJob(id);
      // if Redis is available, also enqueue into BullMQ for faster processing
      if (process.env.REDIS_URL) {
        try {
          const { enqueueUpload } = await import('../../../lib/queue');
          await enqueueUpload(id);
        } catch (e) {
          console.warn('queue enqueue failed', e);
        }
      }
    } else {
      // fallback to in-memory uploadSim
      const { createUpload } = await import('../../../lib/uploadSim');
      createUpload(id, name);
      // start simulated processing in case worker isn't running
      try { const { startProcessing } = await import('../../../lib/uploadSim'); startProcessing(id); } catch (e) {}
    }

    // If a worker is running (DB poller or BullMQ), it will pick up the job and perform real transcoding.
    // Otherwise, the project will fall back to simulated processing (already started above).

    return NextResponse.json({ success: true, file: name, id });
  } catch (err: any) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
'@
Write-TextFile $path $content

# app/api/process/[id]/route.ts
$path = "app/api/process/[id]/route.ts"
$content = @'
import { NextResponse } from 'next/server';
import { getUpload } from '../../../../lib/uploadSim';

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const { id } = params;

  const headers = new Headers({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });

  const stream = new ReadableStream({
    start(controller) {
      function send(data: string) {
        controller.enqueue(new TextEncoder().encode(data));
      }

      let cancelled = false;

      const sendCurrent = () => {
        if (cancelled) return;
        const rec = getUpload(id);
        if (!rec) {
          send(`event: notfound\ndata: ${JSON.stringify({ error: 'not found' })}\n\n`);
          controller.close();
          return;
        }

        send(`event: progress\ndata: ${JSON.stringify({ progress: rec.progress, status: rec.status })}\n\n`);

        if (rec.status === 'done') {
          send(`event: done\ndata: ${JSON.stringify({ file: rec.file })}\n\n`);
          controller.close();
        }
      };

      // send immediately and then poll
      sendCurrent();
      const iv = setInterval(sendCurrent, 500);

      return () => {
        cancelled = true;
        clearInterval(iv);
      };
    }
  });

  return new Response(stream, { headers });
}
'@
Write-TextFile $path $content

# lib/uploadSim.ts
$path = "lib/uploadSim.ts"
$content = @'
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
'@
Write-TextFile $path $content

# lib/transcoder.ts
$path = "lib/transcoder.ts"
$content = @'
import { spawn } from "child_process";
import path from "path";
import fs from "fs";
import { setProgress, setStatus, getUpload } from "./uploadSim";

async function ffprobeDuration(input: string): Promise<number | null> {
  return new Promise((resolve) => {
    const proc = spawn("ffprobe", [
      "-v",
      "error",
      "-show_entries",
      "format=duration",
      "-of",
      "default=noprint_wrappers=1:nokey=1",
      input,
    ]);

    let output = "";
    proc.stdout.on("data", (d) => (output += d.toString()));
    proc.on("close", () => {
      const v = parseFloat(output.trim());
      if (Number.isFinite(v)) resolve(v);
      else resolve(null);
    });
    proc.on("error", () => resolve(null));
  });
}

export async function startTranscode(id: string, input: string, output: string) {
  // update status
  setStatus(id, "processing");

  // try to get duration via ffprobe
  const duration = await ffprobeDuration(input);

  return new Promise<void>((resolve) => {
    // prefer native ffmpeg if available
    const args = [
      "-y",
      "-i",
      input,
      "-c:v",
      "libx264",
      "-preset",
      "veryfast",
      "-crf",
      "23",
      "-c:a",
      "aac",
      "-movflags",
      "+faststart",
      "-progress",
      "pipe:1",
      "-nostats",
      output,
    ];

    const proc = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"] });

    let buffer = "";

    proc.stdout?.on("data", (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() || "";

      const kv: Record<string, string> = {};
      for (const l of lines) {
        const [k, v] = l.split("=");
        if (k && v !== undefined) kv[k.trim()] = v.trim();
      }

      // 'out_time_ms' indicates processed time in ms
      if (kv["out_time_ms"] && duration) {
        const outMs = parseInt(kv["out_time_ms"], 10);
        const percent = Math.min(100, Math.round((outMs / (duration * 1000)) * 100));
        setProgress(id, percent);
      }

      if (kv["progress"] === "end") {
        setProgress(id, 100);
        setStatus(id, "done");
      }
    });

    proc.stderr?.on("data", () => {
      // ignore; ffmpeg may also emit to stderr
    });

    proc.on("close", (code) => {
      const rec = getUpload(id);
      if (rec && rec.status !== "done") {
        if (code === 0) {
          setProgress(id, 100);
          setStatus(id, "done");
        } else {
          setStatus(id, "error");
        }
      }
      resolve();
    });

    proc.on("error", () => {
      // ffmpeg isn't available or fails; fall back to simulated processing
      setStatus(id, "processing");
      resolve();
    });
  });
}

export async function startHlsTranscode(id: string, input: string, outDir: string) {
  // update status
  setStatus(id, "processing");

  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  // variants definition
  const variants = [
    { name: "720p", width: 1280, height: 720, vbr: "2800k", abr: "128k", playlist: "720p.m3u8", bandwidth: 3000000 },
    { name: "480p", width: 854, height: 480, vbr: "1000k", abr: "96k", playlist: "480p.m3u8", bandwidth: 1200000 },
  ];

  let completed = 0;

  for (const v of variants) {
    const playlist = path.join(outDir, v.playlist);
    const args = [
      "-y",
      "-i",
      input,
      "-c:a",
      "aac",
      "-c:v",
      "libx264",
      "-b:v",
      v.vbr,
      "-maxrate",
      v.vbr,
      "-bufsize",
      "2M",
      "-vf",
      `scale=w=${v.width}:h=${v.height}:force_original_aspect_ratio=decrease`,
      "-preset",
      "veryfast",
      "-g",
      "48",
      "-hls_time",
      "4",
      "-hls_playlist_type",
      "vod",
      "-hls_segment_filename",
      path.join(outDir, `${v.name}_%03d.ts`),
      playlist,
    ];

    await new Promise<void>((resolve) => {
      const proc = spawn("ffmpeg", args);
      proc.on("close", (code) => {
        completed++;
        // simple progress estimate
        const percent = Math.min(99, Math.round((completed / variants.length) * 100));
        setProgress(id, percent);
        resolve();
      });
      proc.on("error", () => resolve());
    });
  }

  // write master playlist
  const master = variants.map(v => `#EXT-X-STREAM-INF:BANDWIDTH=${v.bandwidth},RESOLUTION=${v.width}x${v.height}\n${v.playlist}`).join('\n');
  fs.writeFileSync(path.join(outDir, 'master.m3u8'), '#EXTM3U\n' + master);

  setProgress(id, 100);
  setStatus(id, 'done');
}
'@
Write-TextFile $path $content

# lib/db.ts
$path = "lib/db.ts"
$content = @'
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
'@
Write-TextFile $path $content

# lib/queue.ts
$path = "lib/queue.ts"
$content = @'
import { Queue } from 'bullmq';

const connection = process.env.REDIS_URL ? { connectionString: process.env.REDIS_URL } : undefined;

let queue: Queue | null = null;

export function getQueue() {
  if (!process.env.REDIS_URL) return null;
  if (!queue) {
    queue = new Queue('uploads', { connection: connection as any });
  }
  return queue;
}

export async function enqueueUpload(uploadId: string) {
  const q = getQueue();
  if (!q) return null;
  return await q.add('upload', { uploadId });
}
'@
Write-TextFile $path $content

# scripts/worker.js
$path = "scripts/worker.js"
$content = @'
// Simple worker that polls for pending jobs and runs transcoding using lib/transcoder
const path = require('path');
const { fetchNextJob } = require('../lib/db');
const { updateProgress, updateStatus, setOutputFiles } = require('../lib/db');

async function runJob(job) {
  const uploadId = job.upload_id;
  console.log('Processing job', job);
  try {
    const { getUpload } = require('../lib/db');
    const upload = getUpload(uploadId);
    if (!upload) return;
    const input = path.join(process.cwd(), 'public', 'videos', upload.file);
    const outMp4 = path.join(process.cwd(), 'public', 'videos', upload.file + '.transcoded.mp4');

    const { startTranscode, startHlsTranscode } = require('../lib/transcoder');

    await startTranscode(uploadId, input, outMp4);
    // After mp4 is created, produce HLS
    const hlsDir = path.join(process.cwd(), 'public', 'videos', `hls-${uploadId}`);
    await startHlsTranscode(uploadId, outMp4, hlsDir);

    // persist outputs
    setOutputFiles(uploadId, outMp4, hlsDir);
    console.log('Job done', uploadId);
  } catch (e) {
    console.error('Job failed', e);
    try { updateStatus(job.upload_id, 'error'); } catch (e) {}
  }
}

async function loop() {
  // If REDIS_URL is provided, use BullMQ Worker to process jobs from Redis
  const redisUrl = process.env.REDIS_URL;
  if (redisUrl) {
    console.log('REDIS_URL detected, starting BullMQ worker...');
    const { Worker } = require('bullmq');
    const worker = new Worker('uploads', async (job) => {
      if (!job || !job.data) return;
      const uploadId = job.data.uploadId || job.data.upload_id || job.data.uploadID;
      if (!uploadId) return;
      await runJob({ upload_id: uploadId, id: job.id || 0 });
    }, { connection: { connectionString: redisUrl } });

    worker.on('completed', (job) => { console.log('Job completed', job.id); });
    worker.on('failed', (job, err) => { console.error('Job failed', job?.id, err); });

    return; // worker runs and Node process stays alive
  }

  console.log('No REDIS_URL; Worker started, polling for DB/in-memory jobs...');
  while (true) {
    try {
      const job = fetchNextJob();
      if (job) {
        await runJob(job);
      } else {
        // sleep
        await new Promise(r => setTimeout(r, 1500));
      }
    } catch (e) {
      console.error('Worker error', e);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}

loop().catch(err => { console.error(err); process.exit(1); });
'@
Write-TextFile $path $content

# docker-compose.yml
$path = "docker-compose.yml"
$content = @'
version: '3.8'
services:
  redis:
    image: redis:7
    container_name: myvideoplatform_redis
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  ffmpeg:
    image: jrottenberg/ffmpeg:4.4-ubuntu
    container_name: myvideoplatform_ffmpeg
    # This image provides ffmpeg binary; services can reference it.

  app:
    image: node:18
    container_name: myvideoplatform_app
    working_dir: /workspace
    volumes:
      - ./:/workspace
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - REDIS_URL=redis://redis:6379
    command: sh -c "npm ci && npm run dev"
    depends_on:
      - redis
      - ffmpeg

  worker:
    image: node:18
    container_name: myvideoplatform_worker
    working_dir: /workspace
    volumes:
      - ./:/workspace
    environment:
      - NODE_ENV=development
      - REDIS_URL=redis://redis:6379
    command: sh -c "npm ci && npm run worker"
    depends_on:
      - redis
      - ffmpeg
'@
Write-TextFile $path $content

# .github/workflows/playwright-e2e-with-worker.yml
$path = ".github/workflows/playwright-e2e-with-worker.yml"
$content = @'
name: Playwright E2E (with worker)

on:
  push:
  pull_request:

jobs:
  e2e:
    runs-on: ubuntu-latest
    services:
      redis:
        image: redis:7
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm ci
      - name: Install system deps (ffmpeg)
        run: sudo apt-get update && sudo apt-get install -y ffmpeg
      - name: Install Playwright browsers
        run: npx playwright install --with-deps
      - name: Build Next app
        run: npm run build
      - name: Start app
        run: npm run start &
      - name: Start worker (BullMQ)
        env:
          REDIS_URL: redis://127.0.0.1:6379
        run: npm run worker &
      - name: Wait for app
        run: npx wait-on http://localhost:3000
      - name: Run Playwright tests
        run: npx playwright test --project=chromium
'@
Write-TextFile $path $content

# .github/workflows/playwright-e2e.yml (existing)
$path = ".github/workflows/playwright-e2e.yml"
$content = @'
name: Playwright E2E

on:
  push:
  pull_request:

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm ci
      - name: Install system deps (ffmpeg)
        run: sudo apt-get update && sudo apt-get install -y ffmpeg
      - name: Install Playwright browsers
        run: npx playwright install --with-deps
      - name: Build Next app
        run: npm run build
      - name: Start app
        run: npm run start &
      - name: Wait for app
        run: npx wait-on http://localhost:3000
      - name: Run Playwright tests
        run: npx playwright test --project=chromium
'@
Write-TextFile $path $content

# package.json (update
$path = "package.json"
$content = @'
{
  "name": "myvideoplatform",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test:e2e": "playwright test --project=chromium",
    "test:agent": "node agent-test/check.js",
    "test:ci": "npx playwright test --project=chromium",
    "worker": "node scripts/worker.js"
  },
  "dependencies": {
    "next": "16.1.1",
    "react": "19.2.3",
    "react-dom": "19.2.3",
    "bullmq": "^2.11.3",
    "ioredis": "^5.3.2"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "eslint": "^9",
    "eslint-config-next": "16.1.1",
    "tailwindcss": "^4",
    "typescript": "^5",
    "playwright": "^1.36.0",
    "cross-env": "^7.0.3"
  }
}
'@
Write-TextFile $path $content

# tests/e2e/upload.spec.ts
$path = "tests/e2e/upload.spec.ts"
$content = @'
import { test, expect } from '@playwright/test';
import path from 'path';

test('can upload a video and it appears on homepage', async ({ page }) => {
  await page.goto('http://localhost:3000/upload');

  const filePath = path.join(__dirname, '..', 'fixtures', 'blank.mp4');
  const input = await page.locator('input[type=file]');
  await input.setInputFiles(filePath);

  await page.click('button:has-text("Upload")');

  // Wait for processing finished message or redirect
  await page.waitForTimeout(3000);

  // Navigate to home and confirm file exists
  await page.goto('http://localhost:3000/');

  const fileName = 'blank.mp4';
  await expect(page.locator(`text=${fileName}`)).toBeVisible();
});
'@
Write-TextFile $path $content

# tests/fixtures/blank.mp4 (small base64 encoded stub)
$path = "tests/fixtures/blank.mp4"
$base64 = "AAAAAAABZm10YXBwAAAAAAAAbXBwMm1wNDEAAAAAAABmcmVlAAAA"  # tiny stub, not a valid real mp4 but enough for tests
Write-BinaryFileFromBase64 $path $base64

# README.md modifications are already applied; skip rewriting to avoid clobbering other notes

# -------- END FILES --------

Write-Host "All files written. Backup directory: $backupDir"

if ($Commit) {
  Write-Host "Attempting to create branch and commit changes (if git is available)..."
  try {
    $git = & git --version 2>$null
  } catch {
    Write-Host "Git not found in PATH. Install Git to run commits. Exiting."; exit 0
  }

  try {
    $branch = "feat/transcode-worker-ci"
    & git checkout -b $branch
    & git add -A
    & git commit -m "feat: add transcoding worker, HLS, BullMQ, Docker Compose, and CI workflows"
    Write-Host "Committed changes on branch $branch"
  } catch {
    Write-Host "Git commit failed. You can run the following commands manually when Git is available:`n git checkout -b feat/transcode-worker-ci`n git add -A`n git commit -m 'feat: add transcoding worker, HLS, BullMQ, Docker Compose, and CI workflows'"
  }
}
