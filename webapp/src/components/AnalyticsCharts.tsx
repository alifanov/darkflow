"use client";

import { useState } from "react";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from "recharts";

type Row = { label: string; cost: number; tokens: number; runs: number };
type Daily = { day: string; cost: number; tokens: number; runs: number };
type Totals = { cost: number; tokens: number; runs: number };

const ACCENT = "#58a6ff";
const GREEN = "#3fb950";
const BORDER = "#30363d";
const MUTED = "#8b949e";
const SURFACE = "#161b22";
const TEXT = "#e6edf3";

const fmtCost = (n: number) => `$${n.toFixed(n >= 1 ? 2 : 4)}`;
const fmtCostAxis = (n: number) => `$${n.toFixed(n >= 1 ? 0 : 2)}`;
const fmtTokens = (n: number) => n.toLocaleString();
const fmtTokensAxis = (n: number) =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${(n / 1_000).toFixed(0)}k` : `${n}`;

const tooltipStyle = {
  background: SURFACE,
  border: `1px solid ${BORDER}`,
  borderRadius: 8,
  color: TEXT,
  fontSize: 12,
};

type Metric = "cost" | "tokens";

export function AnalyticsCharts({
  daily,
  byProject,
  byModel,
  byRoutine,
  totals,
}: {
  daily: Daily[];
  byProject: Row[];
  byModel: Row[];
  byRoutine: Row[];
  totals: Totals;
}) {
  const [metric, setMetric] = useState<Metric>("cost");

  if (totals.runs === 0) {
    return (
      <p style={{ color: "var(--muted)" }}>
        No usage logged for this period yet. Cost and token data appears once routines run with metrics enabled.
      </p>
    );
  }

  const fmt = metric === "cost" ? fmtCost : fmtTokens;

  return (
    <div className="flex flex-col gap-8">
      {/* Totals */}
      <div className="grid grid-cols-3 gap-4">
        <StatCard label="Total cost" value={fmtCost(totals.cost)} accent={ACCENT} />
        <StatCard label="Total tokens" value={fmtTokens(totals.tokens)} accent={GREEN} />
        <StatCard label="Total runs" value={totals.runs.toLocaleString()} accent={MUTED} />
      </div>

      {/* By day */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-semibold" style={{ color: "var(--text)" }}>
            Over time
          </h2>
          <MetricToggle metric={metric} setMetric={setMetric} />
        </div>
        <div style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={daily} margin={{ top: 8, right: 12, left: 4, bottom: 0 }}>
              <defs>
                <linearGradient id="fillMetric" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={metric === "cost" ? ACCENT : GREEN} stopOpacity={0.35} />
                  <stop offset="95%" stopColor={metric === "cost" ? ACCENT : GREEN} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={BORDER} vertical={false} />
              <XAxis dataKey="day" tick={{ fill: MUTED, fontSize: 11 }} stroke={BORDER} minTickGap={24} />
              <YAxis
                tick={{ fill: MUTED, fontSize: 11 }}
                stroke={BORDER}
                width={52}
                tickFormatter={metric === "cost" ? fmtCostAxis : fmtTokensAxis}
              />
              <Tooltip
                contentStyle={tooltipStyle}
                labelStyle={{ color: MUTED }}
                formatter={(value) => [fmt(Number(value ?? 0)), metric === "cost" ? "Cost" : "Tokens"]}
              />
              <Area
                type="monotone"
                dataKey={metric}
                stroke={metric === "cost" ? ACCENT : GREEN}
                strokeWidth={2}
                fill="url(#fillMetric)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </section>

      {/* Breakdowns */}
      <Breakdown title="By project" rows={byProject} metric={metric} color={ACCENT} dimLabel="Project" />
      <Breakdown title="By model" rows={byModel} metric={metric} color={GREEN} dimLabel="Model" />
      <Breakdown title="By routine" rows={byRoutine} metric={metric} color="#d29922" dimLabel="Routine" />
    </div>
  );
}

function StatCard({ label, value, accent }: { label: string; value: string; accent: string }) {
  return (
    <div
      style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}
    >
      <div className="text-xs uppercase tracking-wider mb-1" style={{ color: "var(--muted)" }}>
        {label}
      </div>
      <div className="text-2xl font-bold font-mono" style={{ color: accent }}>
        {value}
      </div>
    </div>
  );
}

function MetricToggle({ metric, setMetric }: { metric: Metric; setMetric: (m: Metric) => void }) {
  return (
    <div className="flex gap-1">
      {(["cost", "tokens"] as Metric[]).map((m) => {
        const isActive = metric === m;
        return (
          <button
            key={m}
            type="button"
            onClick={() => setMetric(m)}
            className="px-3 py-1 text-sm rounded-md cursor-pointer transition-colors capitalize"
            style={{
              color: isActive ? "var(--text)" : "var(--muted)",
              background: isActive ? "var(--bg)" : "transparent",
              border: `1px solid ${isActive ? "var(--border)" : "transparent"}`,
            }}
          >
            {m}
          </button>
        );
      })}
    </div>
  );
}

function Breakdown({
  title,
  rows,
  metric,
  color,
  dimLabel,
}: {
  title: string;
  rows: Row[];
  metric: Metric;
  color: string;
  dimLabel: string;
}) {
  if (rows.length === 0) return null;
  const top = rows.slice(0, 12);
  const fmt = metric === "cost" ? fmtCost : fmtTokens;

  return (
    <section>
      <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
        {title}
      </h2>
      <div style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}>
        <ResponsiveContainer width="100%" height={Math.max(120, top.length * 32 + 24)}>
          <BarChart data={top} layout="vertical" margin={{ top: 0, right: 16, left: 4, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke={BORDER} horizontal={false} />
            <XAxis
              type="number"
              tick={{ fill: MUTED, fontSize: 11 }}
              stroke={BORDER}
              tickFormatter={metric === "cost" ? fmtCostAxis : fmtTokensAxis}
            />
            <YAxis
              type="category"
              dataKey="label"
              tick={{ fill: MUTED, fontSize: 11 }}
              stroke={BORDER}
              width={140}
            />
            <Tooltip
              cursor={{ fill: "rgba(255,255,255,0.04)" }}
              contentStyle={tooltipStyle}
              labelStyle={{ color: MUTED }}
              formatter={(value) => [fmt(Number(value ?? 0)), metric === "cost" ? "Cost" : "Tokens"]}
            />
            <Bar dataKey={metric} fill={color} radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>

        <table className="w-full border-collapse text-sm mt-4">
          <thead>
            <tr style={{ borderBottom: "1px solid var(--border)" }}>
              {[dimLabel, "Runs", "Tokens", "Cost"].map((c, i) => (
                <th
                  key={c}
                  className={`py-2 px-3 text-xs font-medium uppercase tracking-wider ${i === 0 ? "text-left" : "text-right"}`}
                  style={{ color: "var(--muted)" }}
                >
                  {c}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.label} style={{ borderBottom: "1px solid var(--border)" }}>
                <td className="py-2 px-3">
                  <span
                    className="rounded-full px-2 py-0.5 text-xs font-medium font-mono"
                    style={{ background: "var(--bg)", color: "var(--text)", border: "1px solid var(--border)" }}
                  >
                    {r.label}
                  </span>
                </td>
                <td className="py-2 px-3 text-xs text-right font-mono" style={{ color: "var(--muted)" }}>
                  {r.runs.toLocaleString()}
                </td>
                <td className="py-2 px-3 text-xs text-right font-mono" style={{ color: "var(--muted)" }}>
                  {r.tokens ? r.tokens.toLocaleString() : "—"}
                </td>
                <td className="py-2 px-3 text-xs text-right font-mono" style={{ color: "var(--text)" }}>
                  {r.cost ? `$${r.cost.toFixed(4)}` : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
