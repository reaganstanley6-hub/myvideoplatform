# Agent Test Project

This folder contains a small test harness for the VS Code Agent workflow.

Purpose
- Validate the minimal required files and structure for the video platform project.

Usage
1. From the workspace root, run:

```bash
node agent-test/check.js
```

2. The script will print a JSON summary and exit with code `0` on success, `1` on failure.

Files
- `check.js` — Node script that validates presence and basic content of key files.
- `package.json` — contains a `test` script for convenience.
- `.gitignore` — ignores `node_modules/`.

Notes
- This is a local, read-only verification tool and does not modify your project files.
