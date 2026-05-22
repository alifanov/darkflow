-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "Project" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "repoUrl" TEXT NOT NULL,
    "branch" TEXT NOT NULL DEFAULT 'main',
    "language" TEXT NOT NULL DEFAULT 'English',
    "mergeStrategy" TEXT NOT NULL DEFAULT 'pr',
    "modules" TEXT[],
    "lastSyncedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Project_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Issue" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "state" TEXT NOT NULL DEFAULT 'open',
    "url" TEXT,
    "status" TEXT NOT NULL DEFAULT 'none',
    "priority" TEXT,
    "area" TEXT,
    "source" TEXT,
    "effort" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Issue_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalyticsSnapshot" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "usersTotal" INTEGER,
    "visitors7d" INTEGER,
    "revenue7d" DOUBLE PRECISION,
    "adsSpend7d" DOUBLE PRECISION,
    "currency" TEXT NOT NULL DEFAULT 'USD',
    "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnalyticsSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SecurityStatus" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "openIssues" INTEGER NOT NULL DEFAULT 0,
    "criticalOpen" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ok',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SecurityStatus_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArchitectureStatus" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "openIssues" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ok',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ArchitectureStatus_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoutineLog" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "routine" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoutineLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Project_repoUrl_key" ON "Project"("repoUrl");

-- CreateIndex
CREATE UNIQUE INDEX "Issue_projectId_number_key" ON "Issue"("projectId", "number");

-- CreateIndex
CREATE UNIQUE INDEX "SecurityStatus_projectId_key" ON "SecurityStatus"("projectId");

-- CreateIndex
CREATE UNIQUE INDEX "ArchitectureStatus_projectId_key" ON "ArchitectureStatus"("projectId");

-- AddForeignKey
ALTER TABLE "Issue" ADD CONSTRAINT "Issue_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalyticsSnapshot" ADD CONSTRAINT "AnalyticsSnapshot_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SecurityStatus" ADD CONSTRAINT "SecurityStatus_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArchitectureStatus" ADD CONSTRAINT "ArchitectureStatus_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoutineLog" ADD CONSTRAINT "RoutineLog_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;
