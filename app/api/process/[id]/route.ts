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
