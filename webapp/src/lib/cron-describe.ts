// Human-readable summary of a 5-field cron expression, shown under the cron
// input so "0 */4 * * *" reads as "every 4 hours".
// ponytail: covers the shapes the routine catalog actually uses (fixed time,
// step minutes/hours, weekday, day-of-month). Anything fancier returns "" and
// simply renders no hint — swap in `cronstrue` if that stops being enough.

const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const num = (s: string) => (/^\d+$/.test(s) ? Number(s) : null);
const step = (s: string) => (/^\*\/\d+$/.test(s) ? Number(s.slice(2)) : null);
const plural = (n: number, unit: string) => (n === 1 ? unit : `${n} ${unit}s`);

function atTime(hour: number, minute: number): string {
  return `at ${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function dayNames(dow: string): string | null {
  const parts = dow.split(",").map(num);
  if (parts.some((p) => p === null || p > 7)) return null;
  const names = parts.map((p) => DAYS[p! % 7]);
  return names.length === 1 ? `every ${names[0]}` : `every ${names.join(", ")}`;
}

export function describeCron(cron: string): string {
  const f = cron.trim().split(/\s+/);
  if (f.length !== 5) return "";
  const [min, hour, dom, mon, dow] = f;
  if (mon !== "*") return "";

  const minStep = step(min);
  if (minStep && hour === "*" && dom === "*" && dow === "*") {
    return `every ${plural(minStep, "minute")}`;
  }

  const m = num(min);
  if (m === null) return "";

  if (hour === "*" && dom === "*" && dow === "*") {
    return m === 0 ? "every hour" : `every hour at :${String(m).padStart(2, "0")}`;
  }

  const hourStep = step(hour);
  if (hourStep && dom === "*" && dow === "*") {
    return `every ${plural(hourStep, "hour")}${m ? ` at :${String(m).padStart(2, "0")}` : ""}`;
  }

  const h = num(hour);
  if (h === null) return "";

  if (dom === "*" && dow === "*") return `daily ${atTime(h, m)}`;
  if (dom === "*") {
    const days = dayNames(dow);
    return days ? `${days} ${atTime(h, m)}` : "";
  }
  if (dow === "*") {
    const d = num(dom);
    return d === null ? "" : `monthly on day ${d} ${atTime(h, m)}`;
  }
  return "";
}
