This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project includes a simple local video platform with upload and server-side simulated processing progress. Key files:

- `app/page.tsx` — Homepage (server component) that lists playable videos from `/public/videos`.
- `app/upload/page.tsx` — Upload page (client component) with XHR upload progress and Server-Sent Events for server-side processing progress.
- `app/api/upload/route.ts` — Upload API that saves files to `public/videos` and returns an `id` for processing tracking.
- `app/api/process/[id]/route.ts` — SSE endpoint that streams processing progress for a given upload id.
- `lib/uploadSim.ts` — Simple in-memory upload processing simulator used for SSE progress.
- `agent-test/check.js` — Test script that verifies required files and basic validations.
- `tests/e2e` — Playwright E2E test scaffold (requires `playwright` and browsers).

## Development

Install dependencies and run the dev server:

```bash
npm install
npm run dev
```

Open the site at http://localhost:3000.

## E2E tests (Playwright)

Install Playwright browsers and run tests locally:

```bash
npx playwright install --with-deps
npm run dev
npm run test:e2e
```

Continuous Integration

A GitHub Actions workflow is included at `.github/workflows/playwright-e2e.yml` that runs Playwright tests on pushes and pull requests. It installs system `ffmpeg` on the Ubuntu runner and runs the tests against a built Next.js server.

FFmpeg (Transcoding)

This project attempts to use the `ffmpeg` binary available on the PATH to perform real transcoding and report progress through Server-Sent Events. On your local machine or CI, ensure `ffmpeg` is installed and available. For macOS you can use `brew install ffmpeg`; on Ubuntu/Debian use `sudo apt-get install -y ffmpeg`.

If `ffmpeg` is not available, the system gracefully falls back to simulated processing for progress reporting.

Quick checks

```bash
# run agent checks
npm run test:agent
# run worker locally (will require ffmpeg on PATH for real transcoding)
npm run worker
# run E2E (requires playwright browsers)
npx playwright install --with-deps
npm run dev
npm run test:e2e
```

Worker notes

- The worker polls the DB (or in-memory queue if SQLite not installed) and performs transcoding.
- You can optionally enable Redis + BullMQ for production-grade job queueing and faster job dispatch.

Docker Compose (dev)

A `docker-compose.yml` is included to run Redis and an `ffmpeg` service, and to run the app and worker in containers for local development. Example:

```bash
# start app, redis, ffmpeg, and worker
docker compose up --build
```

To use BullMQ locally with Docker Compose set `REDIS_URL` in your environment to `redis://redis:6379` (the compose file already sets this for the `app` and `worker` services).

- To run a worker locally (Redis):

```bash
# when Redis is running (e.g., via docker compose)
npm run worker
```

- You can run multiple workers for parallel jobs, but for production use consider managed Redis and a job queue service with monitoring.


## Notes

- Uploaded videos are stored in `public/videos` and served statically at `/videos/<filename>`.
- Server-side processing is simulated for demo purposes using an in-memory map. In production you would replace `lib/uploadSim.ts` with real background processing and persistent state.

## Contributing

Pull requests, bug reports, and improvements are welcome.

## Deploy on Vercel

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
