"use client";

import Link from "next/link";

export default function Nav() {
  return (
    <nav className="flex items-center justify-between px-6 py-4 bg-gray-900 text-white">
      <div className="text-xl font-bold">My Video Platform</div>
      <ul className="flex space-x-4 text-sm">
        <li>
          <Link href="/" className="hover:underline">
            Home
          </Link>
        </li>
        <li>
          <Link href="/upload" className="hover:underline">
            Upload
          </Link>
        </li>
      </ul>
    </nav>
  );
}
