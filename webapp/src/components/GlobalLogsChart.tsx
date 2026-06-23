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

export type MinutePoint = { minute: string; ok: number; err: number };

const GREEN = "#3fb950";
const RED = "#ef4444";
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

// Show HH:MM in the viewer's local time.
const fmtMinute = (iso: string) =>
  new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

export function GlobalLogsChart({ data }: { data: MinutePoint[] }) {
  if (data.length === 0) {
    return (
      <p className="mb-6" style={{ color: "var(--muted)" }}>
        No routine runs in the last 24 hours yet.
      </p>
    );
  }

  return (
    <div
      className="mb-6"
      style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}
    >
      <ResponsiveContainer width="100%" height={220}>
        <BarChart data={data} margin={{ top: 8, right: 12, left: 4, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke={BORDER} vertical={false} />
          <XAxis
            dataKey="minute"
            tickFormatter={fmtMinute}
            tick={{ fill: MUTED, fontSize: 11 }}
            stroke={BORDER}
            minTickGap={48}
          />
          <YAxis tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} width={32} allowDecimals={false} />
          <Tooltip
            contentStyle={tooltipStyle}
            labelStyle={{ color: MUTED }}
            labelFormatter={(v) => fmtMinute(String(v))}
            formatter={(value, name) => [value, name === "ok" ? "OK" : "Error"]}
          />
          <Legend
            formatter={(name) => (name === "ok" ? "OK" : "Error")}
            wrapperStyle={{ fontSize: 12, color: MUTED }}
          />
          <Bar dataKey="ok" stackId="t" fill={GREEN} />
          <Bar dataKey="err" stackId="t" fill={RED} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
