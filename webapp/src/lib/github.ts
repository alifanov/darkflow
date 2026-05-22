import { App } from "octokit";

let _app: App | null = null;

function getApp(): App {
  if (_app) return _app;
  const appId = process.env.GITHUB_APP_ID;
  const privateKey = process.env.GITHUB_APP_PRIVATE_KEY;
  if (!appId || !privateKey) {
    throw new Error("GITHUB_APP_ID and GITHUB_APP_PRIVATE_KEY env vars are required");
  }
  _app = new App({ appId, privateKey: privateKey.replace(/\\n/g, "\n") });
  return _app;
}

function parseRepoUrl(repoUrl: string): { owner: string; repo: string } {
  const m = repoUrl.match(/github\.com[/:]([\w.-]+)\/([\w.-]+?)(?:\.git)?$/);
  if (!m) throw new Error(`Cannot parse GitHub repo URL: ${repoUrl}`);
  return { owner: m[1], repo: m[2] };
}

async function getInstallationOctokit(repoUrl: string) {
  const app = getApp();
  const { owner, repo } = parseRepoUrl(repoUrl);
  const installation = await app.octokit.request(
    "GET /repos/{owner}/{repo}/installation",
    { owner, repo }
  );
  return app.getInstallationOctokit(installation.data.id);
}

const STATUS_LABELS = [
  "status:proposed",
  "status:approved",
  "status:rejected",
  "status:needs-info",
  "status:in-progress",
  "status:blocked",
];

export async function setIssueStatus(
  repoUrl: string,
  issueNumber: number,
  newStatus: "approved" | "rejected"
) {
  const octokit = await getInstallationOctokit(repoUrl);
  const { owner, repo } = parseRepoUrl(repoUrl);

  const { data: issue } = await octokit.request(
    "GET /repos/{owner}/{repo}/issues/{issue_number}",
    { owner, repo, issue_number: issueNumber }
  );

  const currentLabels = issue.labels
    .map((l) => (typeof l === "string" ? l : l.name ?? ""))
    .filter(Boolean);

  const newLabels = [
    ...currentLabels.filter((l) => !STATUS_LABELS.includes(l)),
    `status:${newStatus}`,
  ];

  await octokit.request("PATCH /repos/{owner}/{repo}/issues/{issue_number}", {
    owner,
    repo,
    issue_number: issueNumber,
    labels: newLabels,
  });
}
