-- ============================================================
-- KRONOS AI · Integridad de la cadena de auditoría
-- ============================================================

-- ---------- Función de encadenamiento ----------
-- Calcula el hash del registro a partir de su contenido y del hash
-- del registro anterior. Se ejecuta bajo bloqueo consultivo, de modo
-- que dos escrituras concurrentes no puedan leer el mismo antecesor.
CREATE OR REPLACE FUNCTION fn_auditoria_encadenar()
RETURNS TRIGGER AS $$
DECLARE
    v_hash_anterior TEXT;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('kronos_auditoria_chain'));

    SELECT hash_actual INTO v_hash_anterior
    FROM auditoria ORDER BY id DESC LIMIT 1;

    NEW.hash_anterior := v_hash_anterior;
    NEW.hash_actual := encode(
        digest(
            coalesce(v_hash_anterior, '') ||
            coalesce(NEW.ticket_id::text, '') ||
            NEW.action_type ||
            NEW.actor ||
            NEW.payload::text ||
            NEW.timestamp_action::text,
            'sha256'),
        'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_encadenar
    BEFORE INSERT ON auditoria
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_encadenar();

-- ---------- Inmutabilidad impuesta por el motor ----------
-- Rechaza UPDATE y DELETE para todo rol, incluido el propietario.
CREATE OR REPLACE FUNCTION fn_auditoria_inmutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'La tabla auditoria es append-only: % no esta permitido', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_inmutable
    BEFORE UPDATE OR DELETE ON auditoria
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_inmutable();

CREATE TRIGGER trg_cortacircuito_inmutable
    BEFORE UPDATE OR DELETE ON cortacircuito
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_inmutable();

-- ---------- Verificación de continuidad de la cadena ----------
CREATE OR REPLACE FUNCTION fn_verificar_cadena()
RETURNS TABLE (id_roto BIGINT, motivo TEXT) AS $$
DECLARE
    r RECORD;
    v_prev TEXT := NULL;
    v_calc TEXT;
BEGIN
    FOR r IN SELECT * FROM auditoria ORDER BY id LOOP
        IF r.hash_anterior IS DISTINCT FROM v_prev THEN
            id_roto := r.id;
            motivo := 'hash_anterior no coincide con el registro previo';
            RETURN NEXT;
        END IF;

        v_calc := encode(
            digest(
                coalesce(v_prev, '') ||
                coalesce(r.ticket_id::text, '') ||
                r.action_type || r.actor ||
                r.payload::text || r.timestamp_action::text,
                'sha256'),
            'hex');

        IF v_calc <> r.hash_actual THEN
            id_roto := r.id;
            motivo := 'hash_actual no corresponde al contenido del registro';
            RETURN NEXT;
        END IF;

        v_prev := r.hash_actual;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
