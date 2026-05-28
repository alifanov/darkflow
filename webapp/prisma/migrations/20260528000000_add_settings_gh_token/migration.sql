CREATE TABLE "Settings" (
    "id" TEXT NOT NULL DEFAULT 'global',
    "ghToken" TEXT,
    CONSTRAINT "Settings_pkey" PRIMARY KEY ("id")
);
