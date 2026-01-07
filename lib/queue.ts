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
