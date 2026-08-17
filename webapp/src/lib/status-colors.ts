/** Single source of truth for issue-status colors (filter cards, list rows, task page). */
export const STATUS_COLORS: Record<string, string> = {
  proposed: "#1f3a5f",
  approved: "#1a3a1a",
  closed: "#3a1a1a",
  "in-progress": "#2a2a0a",
  "needs-human": "#3a1a3a",
};

export const STATUS_TEXT: Record<string, string> = {
  proposed: "var(--accent)",
  approved: "var(--green)",
  closed: "var(--red)",
  "in-progress": "#e3b341",
  "needs-human": "#c084fc",
};
