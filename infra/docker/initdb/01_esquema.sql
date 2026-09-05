-- ============================================================
-- KRONOS AI · Esquema de persistencia
-- ============================================================
SET timezone = 'America/Santiago';
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- Ciclo de vida del incidente ----------
CREATE TABLE tickets (
    id                   UUID PRIMARY KEY,
    wazuh_alert_id       VARCHAR(64) UNIQUE NOT NULL,
    timestamp_received   TIMESTAMPTZ NOT NULL DEFAULT now(),
    asset_name           VARCHAR(255),
    asset_ip             INET,
    titular_afectado     VARCHAR(255),
    raw_alert_payload    JSONB,
    family_inferred      VARCHAR(2),
    playbook_inferred    VARCHAR(10),
    confidence_family    DECIMAL(3,2),
    confidence_playbook  DECIMAL(3,2),
    autonomia_aplicada   SMALLINT,
    execution_status     VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    rechazo_motivo       VARCHAR(40),
    result_payload       JSONB,
    timestamp_executed   TIMESTAMPTZ,
    reverted_at          TIMESTAMPTZ,
    notificacion_titular VARCHAR(20),
    CONSTRAINT chk_estado CHECK (execution_status IN
        ('PENDING','EXECUTING','SUCCESS','FAILED','REJECTED','MANUAL_TRIAGE')),
    CONSTRAINT chk_nivel CHECK (autonomia_aplicada BETWEEN 0 AND 3),
    CONSTRAINT chk_motivo CHECK (rechazo_motivo IS NULL OR rechazo_motivo IN
        ('esquema','confianza','fuera_catalogo','excluido','tasa',
         'cortacircuito','timeout','sin_titular','humano'))
);

CREATE INDEX idx_tickets_ejec_nivel ON tickets (autonomia_aplicada, timestamp_executed)
    WHERE execution_status = 'SUCCESS';
CREATE INDEX idx_tickets_titular ON tickets (titular_afectado, timestamp_executed)
    WHERE execution_status = 'SUCCESS';
CREATE INDEX idx_tickets_activo ON tickets (asset_name, timestamp_executed);
CREATE INDEX idx_tickets_estado ON tickets (execution_status, timestamp_received DESC);

-- ---------- Auditoría: append-only y encadenada ----------
CREATE TABLE auditoria (
    id                 BIGSERIAL PRIMARY KEY,
    ticket_id          UUID REFERENCES tickets(id),
    action_type        VARCHAR(30) NOT NULL,
    timestamp_action   TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor              VARCHAR(120) NOT NULL,
    payload            JSONB NOT NULL,
    hash_anterior      TEXT,
    hash_actual        TEXT NOT NULL,
    CONSTRAINT chk_accion CHECK (action_type IN
        ('intencion','ejecucion','reversion','rechazo','aprobacion',
         'cortacircuito','arranque','verificacion'))
);
CREATE INDEX idx_auditoria_ticket ON auditoria (ticket_id, id);

-- ---------- Cola de inferencia priorizada ----------
CREATE TABLE cola_inferencia (
    id           BIGSERIAL PRIMARY KEY,
    ticket_id    UUID NOT NULL REFERENCES tickets(id),
    severidad    SMALLINT NOT NULL,
    recibido_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    tomado_en    TIMESTAMPTZ,
    estado       VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT chk_cola CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','EXPIRADO'))
);
CREATE INDEX idx_cola_prioridad ON cola_inferencia (severidad DESC, recibido_en)
    WHERE estado = 'PENDIENTE';

-- ---------- Temporizadores de reversión ----------
CREATE TABLE temporizadores (
    id                  BIGSERIAL PRIMARY KEY,
    ticket_id           UUID NOT NULL REFERENCES tickets(id),
    playbook_id         VARCHAR(10) NOT NULL,
    rutina_reversion    VARCHAR(255) NOT NULL,
    contexto_reversion  JSONB NOT NULL,
    vence_en            TIMESTAMPTZ NOT NULL,
    estado              VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    intentos            SMALLINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_temp CHECK (estado IN
        ('ACTIVO','EN_REVERSION','REVERTIDO','CONFIRMADO','FALLIDO'))
);
CREATE INDEX idx_temp_pendientes ON temporizadores (vence_en) WHERE estado = 'ACTIVO';

-- ---------- Cortacircuito ----------
CREATE TABLE cortacircuito (
    id                 BIGSERIAL PRIMARY KEY,
    disparado          BOOLEAN NOT NULL,
    motivo             VARCHAR(40),
    timestamp_evento   TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor              VARCHAR(120),
    justificacion      TEXT
);

INSERT INTO cortacircuito (disparado, motivo, actor, justificacion)
VALUES (false, 'arranque', 'sistema', 'Estado inicial del sistema');
