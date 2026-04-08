-- 1. Atualizar valores atuais
UPDATE installation_configs
SET serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
value: enterprise
'::text),
    locked = true
WHERE name = 'INSTALLATION_PRICING_PLAN';

UPDATE installation_configs
SET serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
value: 10000
'::text),
    locked = true
WHERE name = 'INSTALLATION_PRICING_PLAN_QUANTITY';

-- 2. Criar função do trigger com casts explícitos
CREATE OR REPLACE FUNCTION force_installation_configs_values()
RETURNS TRIGGER AS $$
DECLARE
    plan_val text := '--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
value: enterprise
';
    qty_val text := '--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
value: 10000
';
BEGIN
    IF NEW.name = 'INSTALLATION_PRICING_PLAN' THEN
        NEW.serialized_value = to_jsonb(plan_val);
        NEW.locked = true; 
    ELSIF NEW.name = 'INSTALLATION_PRICING_PLAN_QUANTITY' THEN
        NEW.serialized_value = to_jsonb(qty_val);
        NEW.locked = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Ativar o trigger
DROP TRIGGER IF EXISTS trg_keep_installation_configs_fixed ON installation_configs;

CREATE TRIGGER trg_keep_installation_configs_fixed
BEFORE INSERT OR UPDATE ON installation_configs
FOR EACH ROW
EXECUTE FUNCTION force_installation_configs_values();
