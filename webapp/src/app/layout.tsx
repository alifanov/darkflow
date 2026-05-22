import type { Metadata } from "next";
import "./globals.css";

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
        <header
          className="border-b px-6 py-4 flex items-center gap-3"
          style={{ borderColor: "var(--border)", background: "var(--surface)" }}
        >
          <span className="text-lg font-semibold tracking-tight">⚡ Dark Flow</span>
        </header>
        <main className="max-w-5xl mx-auto px-6 py-8">{children}</main>
      </body>
    </html>
  );
}
