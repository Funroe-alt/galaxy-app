-- Galaxy: faster downloads and imports.
-- Raises the old Modrinth default of 10 parallel downloads / file writes.
-- Only touches values still at (or below) the old default, so a user's own choice is kept.
UPDATE settings SET max_concurrent_downloads = 24 WHERE max_concurrent_downloads <= 10;
UPDATE settings SET max_concurrent_writes = 32 WHERE max_concurrent_writes <= 10;
