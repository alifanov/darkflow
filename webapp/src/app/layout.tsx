import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
import { FaviconBadge } from "@/components/FaviconBadge";

export const metadata: Metadata = {
  title: "Dark Flow",
  description: "AI workflow dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen" style={{ background: "var(--bg)", color: "var(--text)" }}>
        <FaviconBadge />
        <header
          className="border-b px-6 py-4 flex items-center gap-3"
          style={{ borderColor: "var(--border)", background: "var(--surface)" }}
        >
          <Link
            href="/"
            className="text-lg font-semibold tracking-tight no-underline cursor-pointer hover:opacity-80 transition-opacity"
            style={{ color: "inherit" }}
          >
            ⚡ Dark Flow
          </Link>
        </header>
        <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
      </body>
    </html>
  );
}
