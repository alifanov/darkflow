-- CreateTable
CREATE TABLE "Email" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "uid" TEXT,
    "messageId" TEXT NOT NULL,
    "fromAddr" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "seen" BOOLEAN NOT NULL DEFAULT false,
    "sentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Email_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Email_projectId_sentAt_idx" ON "Email"("projectId", "sentAt");

-- CreateIndex
CREATE UNIQUE INDEX "Email_projectId_messageId_key" ON "Email"("projectId", "messageId");

-- AddForeignKey
ALTER TABLE "Email" ADD CONSTRAINT "Email_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;
