import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Standalone output is only used for the Docker image (the Dockerfile copies
  // .next/standalone and runs `node server.js`). On the host we run `next start`,
  // which is incompatible with standalone output — so gate it behind DOCKER_BUILD.
  ...(process.env.DOCKER_BUILD ? { output: "standalone" as const } : {}),
};

export default nextConfig;
