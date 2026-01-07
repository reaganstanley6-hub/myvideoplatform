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



