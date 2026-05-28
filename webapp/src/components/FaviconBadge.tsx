"use client";

import { useEffect } from "react";

const BASE_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#0d1117"/>
  <rect x="1" y="1" width="62" height="62" rx="13" fill="none" stroke="#30363d" stroke-width="2"/>
  <path d="M36 8 L18 36 H30 L28 56 L46 28 H34 Z" fill="#58a6ff"/>
</svg>`;

const BASE_SVG_WITH_BADGE = (label: string) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#0d1117"/>
  <rect x="1" y="1" width="62" height="62" rx="13" fill="none" stroke="#30363d" stroke-width="2"/>
  <path d="M36 8 L18 36 H30 L28 56 L46 28 H34 Z" fill="#58a6ff"/>
  <circle cx="47" cy="17" r="15" fill="#ef4444"/>
  <text x="47" y="22" text-anchor="middle" font-family="Arial,sans-serif" font-size="${label.length > 1 ? "13" : "16"}" font-weight="bold" fill="white">${label}</text>
</svg>`;

function svgToDataUrl(svg: string) {
  return "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)));
}

function setFavicon(href: string) {
  let link = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
  if (!link) {
    link = document.createElement("link");
    link.rel = "icon";
    document.head.appendChild(link);
  }
  link.href = href;
}

async function updateFavicon() {
  try {
    const res = await fetch("/api/needs-human-count");
    if (!res.ok) return;
    const { count } = await res.json();
    const svg =
      count > 0
        ? BASE_SVG_WITH_BADGE(count > 99 ? "99+" : String(count))
        : BASE_SVG;
    setFavicon(svgToDataUrl(svg));
  } catch {
    // silently ignore network errors
  }
}

export function FaviconBadge() {
  useEffect(() => {
    updateFavicon();
    const interval = setInterval(updateFavicon, 30_000);
    return () => clearInterval(interval);
  }, []);

  return null;
}
