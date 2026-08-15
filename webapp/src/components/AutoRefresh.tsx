"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

// The header badge is server-rendered, so a tab left open keeps showing the
// worker version/liveness from page-load time. Re-fetch the RSC payload on a
// timer; client state (form inputs, scroll) survives a router.refresh().
export function AutoRefresh({ seconds = 30 }: { seconds?: number }) {
  const router = useRouter();

  useEffect(() => {
    const id = setInterval(() => {
      if (document.visibilityState === "visible") router.refresh();
    }, seconds * 1000);
    return () => clearInterval(id);
  }, [router, seconds]);

  return null;
}
