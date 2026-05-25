"use client";

import { useEffect, useState } from "react";

const pad = (n: number) => n.toString().padStart(2, "0");

function formatLocal(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function formatRelative(d: Date, now: number): string {
  const diffMs = now - d.getTime();
  const future = diffMs < 0;
  const abs = Math.abs(diffMs);
  const sec = Math.floor(abs / 1000);
  if (sec < 5) return "just now";
  if (sec < 60) return future ? `in ${sec}s` : `${sec}s ago`;
  const min = Math.floor(sec / 60);
  if (min < 60) return future ? `in ${min}m` : `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return future ? `in ${hr}h` : `${hr}h ago`;
  const day = Math.floor(hr / 24);
  if (day < 30) return future ? `in ${day}d` : `${day}d ago`;
  const mo = Math.floor(day / 30);
  if (mo < 12) return future ? `in ${mo}mo` : `${mo}mo ago`;
  const yr = Math.floor(day / 365);
  return future ? `in ${yr}y` : `${yr}y ago`;
}

export function LocalTime({ date }: { date: string | Date }) {
  const d = typeof date === "string" ? new Date(date) : date;
  const [now, setNow] = useState(() => d.getTime());

  useEffect(() => {
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);

  return (
    <span suppressHydrationWarning>
      {formatLocal(d)}{" "}
      <span style={{ opacity: 0.7 }}>({formatRelative(d, now)})</span>
    </span>
  );
}
