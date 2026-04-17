-- analysis_states schema migration
-- Purpose:
-- 1. Normalize existing analysis_states table to the current contract
-- 2. Remove legacy duplicate rows before restoring name uniqueness
-- 3. Recreate canonical unique indexes for workspace and personal tasks

ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS workspace_id VARCHAR(50);
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS scope VARCHAR(50);
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS module_type VARCHAR(100);
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_name VARCHAR(255);
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_payload TEXT;
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_note TEXT;
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE analysis_states ALTER COLUMN state_payload TYPE TEXT USING state_payload::text;
ALTER TABLE analysis_states ALTER COLUMN state_note TYPE TEXT USING state_note::text;
ALTER TABLE analysis_states ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE analysis_states ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;

UPDATE analysis_states
SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP),
    created_at = COALESCE(created_at, updated_at, CURRENT_TIMESTAMP);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'analysis_states'::regclass
      AND conname = 'analysis_states_workspace_fk'
  ) THEN
    ALTER TABLE analysis_states
    ADD CONSTRAINT analysis_states_workspace_fk
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
DECLARE rec RECORD;
BEGIN
  FOR rec IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'analysis_states'::regclass
      AND contype = 'u'
  LOOP
    EXECUTE format('ALTER TABLE analysis_states DROP CONSTRAINT IF EXISTS %I', rec.conname);
  END LOOP;
END $$;

WITH ranked AS (
  SELECT ctid,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, workspace_id, scope, module_type, state_name
           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC
         ) AS rn
  FROM analysis_states
  WHERE workspace_id IS NOT NULL
    AND COALESCE(BTRIM(scope), '') <> ''
    AND COALESCE(BTRIM(module_type), '') <> ''
    AND COALESCE(BTRIM(state_name), '') <> ''
)
DELETE FROM analysis_states target
USING ranked
WHERE target.ctid = ranked.ctid
  AND ranked.rn > 1;

WITH ranked AS (
  SELECT ctid,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, scope, module_type, state_name
           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC
         ) AS rn
  FROM analysis_states
  WHERE workspace_id IS NULL
    AND COALESCE(BTRIM(scope), '') <> ''
    AND COALESCE(BTRIM(module_type), '') <> ''
    AND COALESCE(BTRIM(state_name), '') <> ''
)
DELETE FROM analysis_states target
USING ranked
WHERE target.ctid = ranked.ctid
  AND ranked.rn > 1;

CREATE INDEX IF NOT EXISTS idx_analysis_states_user_scope
    ON analysis_states(user_id, scope);
CREATE INDEX IF NOT EXISTS idx_analysis_states_workspace_module
    ON analysis_states(workspace_id, module_type);

CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_workspace_scope_module_name
    ON analysis_states(user_id, workspace_id, scope, module_type, state_name)
    WHERE workspace_id IS NOT NULL
      AND COALESCE(BTRIM(scope), '') <> ''
      AND COALESCE(BTRIM(module_type), '') <> ''
      AND COALESCE(BTRIM(state_name), '') <> '';

CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_scope_module_name_personal
    ON analysis_states(user_id, scope, module_type, state_name)
    WHERE workspace_id IS NULL
      AND COALESCE(BTRIM(scope), '') <> ''
      AND COALESCE(BTRIM(module_type), '') <> ''
      AND COALESCE(BTRIM(state_name), '') <> '';
