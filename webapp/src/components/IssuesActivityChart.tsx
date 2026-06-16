"use client";

import {
  ResponsiveContainer,
  BarChart,
  Bar,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  ReferenceLine,
  Tooltip,
  Legend,
} from "recharts";

export type IssueActivityDay = { day: string; created: number; closed: number };

const ACCENT = "#58a6ff";
const GREEN = "#3fb950";
const RED = "#f85149";
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

function cardStyle() {
  return {
    border: "1px solid var(--border)",
    borderRadius: 8,
    padding: 16,
    background: "var(--surface)",
  } as const;
}

function ChartHeader({ title }: { title: string }) {
  return (
    <div className="flex items-center justify-between mb-3">
      <h2 className="text-sm font-semibold" style={{ color: "var(--text)" }}>
        {title}
      </h2>
      <span className="text-xs" style={{ color: "var(--muted)" }}>
        all projects
      </span>
    </div>
  );
}

const EMPTY_NOTE = (
  <p className="text-sm py-8 text-center" style={{ color: "var(--muted)" }}>
    No issue activity in the last 7 days. Timestamps populate once each project&apos;s worker syncs
    after updating.
  </p>
);

export function IssuesActivityChart({ data }: { data: IssueActivityDay[] }) {
  const hasActivity = data.some((d) => d.created > 0 || d.closed > 0);

  // net = created − closed → positive means the open-issue backlog grew that day
  const net = data.map((d) => ({ ...d, net: d.created - d.closed }));

  return (
    <div className="grid gap-4" style={{ gridTemplateColumns: "1fr 1fr" }}>
      <div style={cardStyle()}>
        <ChartHeader title="Issues — last 7 days" />
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
          EMPTY_NOTE
        )}
      </div>

      <div style={cardStyle()}>
        <ChartHeader title="Net change — last 7 days" />
        {hasActivity ? (
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={net} margin={{ top: 8, right: 12, left: 4, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={BORDER} vertical={false} />
              <XAxis dataKey="day" tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} />
              <YAxis tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} width={32} allowDecimals={false} />
              <ReferenceLine y={0} stroke={MUTED} />
              <Tooltip
                cursor={{ fill: "rgba(255,255,255,0.04)" }}
                contentStyle={tooltipStyle}
                labelStyle={{ color: MUTED }}
                formatter={(v) => {
                  const n = Number(v);
                  return [n > 0 ? `+${n}` : `${n}`, "Created − Closed"];
                }}
              />
              <Bar dataKey="net" name="Net (created − closed)" radius={[3, 3, 0, 0]}>
                {net.map((d, i) => (
                  <Cell key={i} fill={d.net > 0 ? RED : GREEN} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        ) : (
          EMPTY_NOTE
        )}
      </div>
    </div>
  );
}
