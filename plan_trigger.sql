UPDATE installation_configs
SET serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: enterprise\n'),
    locked = true
WHERE name = 'INSTALLATION_PRICING_PLAN';

UPDATE installation_configs
SET serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: 10000\n'),
    locked = true
WHERE name = 'INSTALLATION_PRICING_PLAN_QUANTITY';

CREATE OR REPLACE FUNCTION force_installation_configs_values()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name = 'INSTALLATION_PRICING_PLAN' THEN
        NEW.serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: enterprise\n');
        NEW.locked = true; 
    END IF;

    IF NEW.name = 'INSTALLATION_PRICING_PLAN_QUANTITY' THEN
        NEW.serialized_value = to_jsonb('--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: 10000\n');
        NEW.locked = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_keep_installation_configs_fixed ON installation_configs;

CREATE TRIGGER trg_keep_installation_configs_fixed
BEFORE INSERT OR UPDATE ON installation_configs
FOR EACH ROW
EXECUTE FUNCTION force_installation_configs_values();
