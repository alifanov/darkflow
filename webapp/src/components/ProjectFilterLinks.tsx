"use client";

import Link from "next/link";

const ACTIVE_FILTERS = [
  { key: "all", label: "All" },
  { key: "active", label: "Active" },
  { key: "inactive", label: "Paused" },
] as const;

export function ProjectFilterLinks({ activeFilter }: { activeFilter: string }) {
  return (
    <div className="flex items-center gap-1 ml-2">
      {ACTIVE_FILTERS.map((f) => {
        const isSelected = f.key === activeFilter;
        const href = f.key === "all" ? "/" : `/?active=${f.key}`;
        return (
          <Link
            key={f.key}
            href={href}
            onClick={() => {
              document.cookie = `projectsFilter=${f.key}; path=/; max-age=31536000`;
            }}
            className="rounded-full px-3 py-1 text-xs font-medium"
            style={{
              background: isSelected ? "var(--accent)" : "var(--surface)",
              color: isSelected ? "#fff" : "var(--muted)",
              border: "1px solid var(--border)",
            }}
          >
            {f.label}
          </Link>
        );
      })}
    </div>
  );
}
