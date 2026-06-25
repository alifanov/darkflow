"use client";

import { useMemo, useState } from "react";
import { LogRow, logIsError } from "@/components/LogRow";

export interface RoutineLogItem {
  id: string;
  routine: string;
  summary: string;
  output: string | null;
  costUsd: number | null;
  totalTokens: number | null;
  timestamp: string;
  project?: string;
}

type SortKey = "time" | "status";
type SortDir = "asc" | "desc";
type StatusFilter = "all" | "errors" | "success";

export function RoutineLogsTable({ logs }: { logs: RoutineLogItem[] }) {
  const [sortKey, setSortKey] = useState<SortKey>("time");
  const [sortDir, setSortDir] = useState<SortDir>("desc");
  const [filter, setFilter] = useState<StatusFilter>("all");

  function toggleSort(key: SortKey) {
    if (key === sortKey) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortKey(key);
      // Default to descending: newest-first for time, errors-first for status.
      setSortDir("desc");
    }
  }

  const sorted = useMemo(() => {
    let arr = logs.map((l) => ({ ...l, isError: logIsError(l.summary) }));
    if (filter === "errors") arr = arr.filter((l) => l.isError);
    else if (filter === "success") arr = arr.filter((l) => !l.isError);
    arr.sort((a, b) => {
      let cmp = 0;
      if (sortKey === "status") {
        cmp = Number(a.isError) - Number(b.isError);
        if (cmp === 0) cmp = a.timestamp.localeCompare(b.timestamp);
      } else {
        cmp = a.timestamp.localeCompare(b.timestamp);
      }
      return sortDir === "asc" ? cmp : -cmp;
    });
    return arr;
  }, [logs, sortKey, sortDir, filter]);

  const arrow = (key: SortKey) => (sortKey === key ? (sortDir === "asc" ? " ▲" : " ▼") : "");

  const showProject = logs.some((l) => l.project != null);

  return (
    <div>
      <div className="flex gap-2 mb-3">
        {(["all", "errors", "success"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className="text-xs px-3 py-1 rounded-full capitalize cursor-pointer"
            style={{
              border: "1px solid var(--border)",
              background: filter === f ? "var(--surface)" : "transparent",
              color: filter === f ? "var(--text)" : "var(--muted)",
              fontWeight: filter === f ? 600 : 400,
            }}
          >
            {f}
          </button>
        ))}
      </div>
      <div style={{ border: "1px solid var(--border)", borderRadius: 8, overflow: "hidden" }}>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
            <SortHeader label="Time" onClick={() => toggleSort("time")} suffix={arrow("time")} />
            {showProject && <Header label="Project" />}
            <Header label="Routine" />
            <Header label="Summary" />
            <SortHeader label="Status" onClick={() => toggleSort("status")} suffix={arrow("status")} />
            <Header label="Tokens" align="left" />
            <Header label="Cost" align="left" />
            <Header label="" />
          </tr>
        </thead>
        <tbody>
          {sorted.map((l) => (
            <LogRow
              key={l.id}
              id={l.id}
              routine={l.routine}
              summary={l.summary}
              output={l.output}
              costUsd={l.costUsd}
              totalTokens={l.totalTokens}
              timestamp={l.timestamp}
              isError={l.isError}
              project={l.project}
            />
          ))}
        </tbody>
      </table>
      </div>
    </div>
  );
}

function Header({ label, align = "left" }: { label: string; align?: "left" | "right" }) {
  return (
    <th
      className={`py-2 px-4 text-xs font-medium uppercase tracking-wider text-${align}`}
      style={{ color: "var(--muted)" }}
    >
      {label}
    </th>
  );
}

function SortHeader({ label, onClick, suffix }: { label: string; onClick: () => void; suffix: string }) {
  return (
    <th
      onClick={onClick}
      className="py-2 px-4 text-xs font-medium uppercase tracking-wider text-left select-none cursor-pointer"
      style={{ color: "var(--muted)" }}
    >
      {label}
      {suffix}
    </th>
  );
}
