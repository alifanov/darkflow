// `/api/tasks/[number]` takes the task number from the path, so it is a string
// that nothing has checked yet. `Number("undefined")` is NaN, and Prisma answers
// a NaN in a compound key with "Argument `number` is missing" — a 500 on what is
// really a malformed request.
//
// Returns the task number, or null when the segment is not a positive integer.
// "1.5", "1e3", " 1", "" and "undefined" are all rejected: a task number is
// digits, nothing else.
export function parseTaskNumber(raw: string): number | null {
  if (!/^\d+$/.test(raw)) return null;
  const n = Number(raw);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}
