const fs = require('fs');
const path = require('path');

const workspaceRoot = process.cwd();

const checks = [];

function exists(relPath) {
  const p = path.join(workspaceRoot, relPath);
  return fs.existsSync(p);
}

function read(relPath) {
  const p = path.join(workspaceRoot, relPath);
  try { return fs.readFileSync(p, 'utf8'); } catch (e) { return null; }
}

// Check 1: app/page.tsx exists and is a Server Component (no "use client")
const homepagePath = 'app/page.tsx';
const homepageExists = exists(homepagePath);
const homepageContent = homepageExists ? read(homepagePath) : null;
const homepageIsServer = homepageExists && homepageContent && !homepageContent.includes('use client');
checks.push({ file: homepagePath, exists: homepageExists, isServer: homepageIsServer });

// ensure globals.css contains Tailwind directives
const globalsPath = 'app/globals.css';
const globalsExists = exists(globalsPath);
const globalsContent = globalsExists ? read(globalsPath) : null;
const hasTailwind = globalsContent && (globalsContent.includes('@tailwind base') || globalsContent.includes('@tailwind utilities'));
checks.push({ file: globalsPath, exists: globalsExists, hasTailwind: !!hasTailwind });

// Check 2: app/upload/page.tsx exists and is a Client Component (has "use client")
const uploadPath = 'app/upload/page.tsx';
const uploadExists = exists(uploadPath);
const uploadContent = uploadExists ? read(uploadPath) : null;
const uploadIsClient = uploadExists && uploadContent && uploadContent.includes('use client');
checks.push({ file: uploadPath, exists: uploadExists, isClient: uploadIsClient });

// Check 3: app/api/upload/route.ts exists and contains expected keywords
const apiPath = 'app/api/upload/route.ts';
const apiExists = exists(apiPath);
const apiContent = apiExists ? read(apiPath) : null;
const apiHasFormData = apiContent && apiContent.includes('formData');
const apiHasWriteFile = apiContent && apiContent.includes('writeFile');
const apiHasProcessCwd = apiContent && apiContent.includes('process.cwd');
checks.push({ file: apiPath, exists: apiExists, hasFormData: !!apiHasFormData, hasWriteFile: !!apiHasWriteFile, hasProcessCwd: !!apiHasProcessCwd });

// Check 4: public/videos directory exists
const videosPath = 'public/videos';
const videosExists = exists(videosPath) && fs.statSync(path.join(workspaceRoot, videosPath)).isDirectory();
checks.push({ file: videosPath, exists: videosExists });

// Check 5: validate files in public/videos for allowed extensions and size
const allowed = ['.mp4', '.webm', '.ogg', '.mov', '.mkv'];
const maxBytes = 500 * 1024 * 1024; // 500 MB
let videoChecks = { files: [] };
if (videosExists) {
  const items = fs.readdirSync(path.join(workspaceRoot, videosPath));
  for (const f of items) {
    try {
      const p = path.join(workspaceRoot, videosPath, f);
      const stat = fs.statSync(p);
      const ext = path.extname(f).toLowerCase();
      const okExt = allowed.includes(ext);
      const okSize = stat.size <= maxBytes;
      videoChecks.files.push({ name: f, ext, size: stat.size, okExt, okSize });
    } catch (e) {
      videoChecks.files.push({ name: f, error: String(e) });
    }
  }
}
checks.push({ file: videosPath + '/*', details: videoChecks });

const allPass = checks.every(c => {
  if (c.file === homepagePath) return c.exists && c.isServer;
  if (c.file === globalsPath) return c.exists && c.hasTailwind;
  if (c.file === uploadPath) return c.exists && c.isClient;
  if (c.file === apiPath) return c.exists && c.hasFormData && c.hasWriteFile && c.hasProcessCwd;
  if (c.file === videosPath) return c.exists;
  if (c.file === videosPath + '/*') {
    // allow empty folder; otherwise ensure all files meet ext and size
    if (!c.details || !c.details.files || c.details.files.length === 0) return true;
    return c.details.files.every(f => f.okExt && f.okSize && !f.error);
  }
  return false;
});

const result = { success: !!allPass, checks };

console.log(JSON.stringify(result, null, 2));

process.exit(allPass ? 0 : 1);
