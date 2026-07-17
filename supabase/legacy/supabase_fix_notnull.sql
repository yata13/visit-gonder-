-- Remove NOT NULL from guides columns
ALTER TABLE guides ALTER COLUMN initials DROP NOT NULL;

-- Done
SELECT 'NOT NULL constraints removed' AS result;
