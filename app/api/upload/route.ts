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

    // create upload record and start processing simulation
    const id = `${Date.now()}-${Math.random().toString(36).slice(2,8)}`;
    try {
    // record upload in DB (if available) and enqueue a job
    let db = null;
    try { db = await import('../../../lib/db'); } catch (e) { db = null; }

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
    } catch (e) {
      // non-fatal — at worst we'll have simulated processing
      console.warn('transcoder unavailable', e);
    }

    return NextResponse.json({ success: true, file: name, id });
  } catch (err: any) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
