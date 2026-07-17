-- Emergency Requests table
CREATE TABLE IF NOT EXISTS emergency_requests (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type        text DEFAULT 'message',  -- call / message / transport / sos
  name        text,
  phone       text,
  message     text,
  location    text,
  status      text DEFAULT 'pending',  -- pending / responding / resolved
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE emergency_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "em_select" ON emergency_requests FOR SELECT USING (true);
CREATE POLICY "em_insert" ON emergency_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "em_update" ON emergency_requests FOR UPDATE USING (true);
CREATE POLICY "em_delete" ON emergency_requests FOR DELETE USING (true);

SELECT 'Emergency table ready!' AS result;
