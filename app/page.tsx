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
