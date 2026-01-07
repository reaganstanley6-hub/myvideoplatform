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