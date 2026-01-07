import { spawn } from 'child_process';
import path from 'path';
import { setProgress, setStatus, getUpload } from './uploadSim';

async function ffprobeDuration(input: string): Promise<number | null> {
  return new Promise((resolve) => {
    const proc = spawn('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      input,
    ]);

    let output = '';
    proc.stdout.on('data', (d) => (output += d.toString()));
    proc.on('close', () => {
      const v = parseFloat(output.trim());
      if (Number.isFinite(v)) resolve(v);
      else resolve(null);
    });
    proc.on('error', () => resolve(null));
  });
}

export async function startTranscode(id: string, input: string, output: string) {
  // update status
  setStatus(id, 'processing');

  // try to get duration via ffprobe
  const duration = await ffprobeDuration(input);

  return new Promise<void>((resolve) => {
    // prefer native ffmpeg if available
    const args = [
      '-y',
      '-i', input,
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '23',
      '-c:a', 'aac',
      '-movflags', '+faststart',
      '-progress', 'pipe:1',
      '-nostats',
      output,
    ];

    const proc = spawn('ffmpeg', args, { stdio: ['ignore', 'pipe', 'pipe'] });

    let buffer = '';

    proc.stdout?.on('data', (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() || '';

      const kv: Record<string, string> = {};
      for (const l of lines) {
        const [k, v] = l.split('=');
        if (k && v !== undefined) kv[k.trim()] = v.trim();
      }

      // 'out_time_ms' indicates processed time in ms
      if (kv['out_time_ms'] && duration) {
        const outMs = parseInt(kv['out_time_ms'], 10);
        const percent = Math.min(100, Math.round((outMs / (duration * 1000)) * 100));
        setProgress(id, percent);
      }

      if (kv['progress'] === 'end') {
        setProgress(id, 100);
        setStatus(id, 'done');
      }
    });

    proc.stderr?.on('data', () => {
      // ignore; ffmpeg may also emit to stderr
    });

    proc.on('close', (code) => {
      const rec = getUpload(id);
      if (rec && rec.status !== 'done') {
        if (code === 0) {
          setProgress(id, 100);
          setStatus(id, 'done');
        } else {
          setStatus(id, 'error');
        }
      }
      resolve();
    });

    proc.on('error', () => {
      // ffmpeg isn't available or fails; fall back to simulated processing
      setStatus(id, 'processing');
      resolve();
    });
  });
}

export async function startHlsTranscode(id: string, input: string, outDir: string) {
  // update status
  setStatus(id, 'processing');

  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  // variants definition
  const variants = [
    { name: '720p', width: 1280, height: 720, vbr: '2800k', abr: '128k', playlist: '720p.m3u8', bandwidth: 3000000 },
    { name: '480p', width: 854, height: 480, vbr: '1000k', abr: '96k', playlist: '480p.m3u8', bandwidth: 1200000 },
  ];

  let completed = 0;

  for (const v of variants) {
    const playlist = path.join(outDir, v.playlist);
    const args = [
      '-y',
      '-i', input,
      '-c:a', 'aac',
      '-c:v', 'libx264',
      '-b:v', v.vbr,
      '-maxrate', v.vbr,
      '-bufsize', '2M',
      '-vf', `scale=w=${v.width}:h=${v.height}:force_original_aspect_ratio=decrease`,
      '-preset', 'veryfast',
      '-g', '48',
      '-hls_time', '4',
      '-hls_playlist_type', 'vod',
      '-hls_segment_filename', path.join(outDir, `${v.name}_%03d.ts`),
      playlist,
    ];

    await new Promise<void>((resolve) => {
      const proc = spawn('ffmpeg', args);
      proc.on('close', (code) => {
        completed++;
        // simple progress estimate
        const percent = Math.min(99, Math.round((completed / variants.length) * 100));
        setProgress(id, percent);
        resolve();
      });
      proc.on('error', () => resolve());
    });
  }

  // write master playlist
  const master = variants.map(v => `#EXT-X-STREAM-INF:BANDWIDTH=${v.bandwidth},RESOLUTION=${v.width}x${v.height}\n${v.playlist}`).join('\n');
  fs.writeFileSync(path.join(outDir, 'master.m3u8'), '#EXTM3U\n' + master);

  setProgress(id, 100);
  setStatus(id, 'done');
}

