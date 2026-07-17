-- ============================================================
--  READ-ONLY inspection — run in Supabase SQL editor to get the
--  authoritative RLS state that the anon REST API cannot expose.
--  Safe: selects only, changes nothing.
-- ============================================================

-- 1. Which tables have RLS enabled?
select n.nspname as schema,
       c.relname as table,
       c.relrowsecurity  as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;

-- 2. Every policy currently defined, with its USING / WITH CHECK.
select schemaname, tablename, policyname,
       cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3. Table-level grants to anon / authenticated (the layer beneath RLS).
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon','authenticated')
order by table_name, grantee, privilege_type;
