-- P5: one new field — the staging URL. Commands that need pages to walk read sitemap.xml.
ALTER TABLE "Project" ADD COLUMN "stagingUrl" TEXT;
