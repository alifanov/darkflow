"use client";

import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from "recharts";

export type IssueActivityDay = { day: string; created: number; closed: number };

const ACCENT = "#58a6ff";
const GREEN = "#3fb950";
const BORDER = "#30363d";
const MUTED = "#8b949e";
const SURFACE = "#161b22";
const TEXT = "#e6edf3";

const tooltipStyle = {
  background: SURFACE,
  border: `1px solid ${BORDER}`,
  borderRadius: 8,
  color: TEXT,
  fontSize: 12,
};

export function IssuesActivityChart({ data }: { data: IssueActivityDay[] }) {
  const hasActivity = data.some((d) => d.created > 0 || d.closed > 0);

  return (
    <div
      style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}
    >
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-semibold" style={{ color: "var(--text)" }}>
          Issues — last 7 days
        </h2>
        <span className="text-xs" style={{ color: "var(--muted)" }}>
          all projects
        </span>
      </div>
      {hasActivity ? (
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={data} margin={{ top: 8, right: 12, left: 4, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke={BORDER} vertical={false} />
            <XAxis dataKey="day" tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} />
            <YAxis tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} width={32} allowDecimals={false} />
            <Tooltip
              cursor={{ fill: "rgba(255,255,255,0.04)" }}
              contentStyle={tooltipStyle}
              labelStyle={{ color: MUTED }}
            />
            <Legend wrapperStyle={{ fontSize: 12, color: MUTED }} iconType="circle" />
            <Bar dataKey="created" name="Created" stackId="a" fill={ACCENT} radius={[0, 0, 0, 0]} />
            <Bar dataKey="closed" name="Closed" stackId="a" fill={GREEN} radius={[3, 3, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      ) : (
        <p className="text-sm py-8 text-center" style={{ color: "var(--muted)" }}>
          No issue activity in the last 7 days. Timestamps populate once each project&apos;s worker
          syncs after updating.
        </p>
      )}
    </div>
  );
}
