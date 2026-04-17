-- Row-Level Security (RLS)

ALTER TABLE mascotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE mascotas FORCE ROW LEVEL SECURITY;

ALTER TABLE citas ENABLE ROW LEVEL SECURITY;
ALTER TABLE citas FORCE ROW LEVEL SECURITY;

ALTER TABLE vacunas_aplicadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE vacunas_aplicadas FORCE ROW LEVEL SECURITY;

-- Mascotas
CREATE POLICY mascotas_admin_all
ON mascotas
FOR ALL
TO role_admin
USING (true)
WITH CHECK (true);

CREATE POLICY mascotas_recepcion_all
ON mascotas
FOR SELECT
TO role_recepcion
USING (true);

CREATE POLICY mascotas_vet_select
ON mascotas
FOR SELECT
TO role_vet
USING (
    EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = mascotas.id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);

-- Citas
CREATE POLICY citas_admin_all
ON citas
FOR ALL
TO role_admin
USING (true)
WITH CHECK (true);

CREATE POLICY citas_recepcion_all
ON citas
FOR ALL
TO role_recepcion
USING (true)
WITH CHECK (true);

CREATE POLICY citas_vet_select
ON citas
FOR SELECT
TO role_vet
USING (
    citas.veterinario_id = current_setting('app.current_vet_id', true)::INT
);

CREATE POLICY citas_vet_write
ON citas
FOR INSERT
TO role_vet
WITH CHECK (
    citas.veterinario_id = current_setting('app.current_vet_id', true)::INT
    AND EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = citas.mascota_id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);

CREATE POLICY citas_vet_update
ON citas
FOR UPDATE
TO role_vet
USING (
    citas.veterinario_id = current_setting('app.current_vet_id', true)::INT
)
WITH CHECK (
    citas.veterinario_id = current_setting('app.current_vet_id', true)::INT
    AND EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = citas.mascota_id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);

-- Vacunas aplicadas
CREATE POLICY vacunas_admin_all
ON vacunas_aplicadas
FOR ALL
TO role_admin
USING (true)
WITH CHECK (true);

CREATE POLICY vacunas_vet_select
ON vacunas_aplicadas
FOR SELECT
TO role_vet
USING (
    EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = vacunas_aplicadas.mascota_id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);

CREATE POLICY vacunas_vet_insert
ON vacunas_aplicadas
FOR INSERT
TO role_vet
WITH CHECK (
    vacunas_aplicadas.veterinario_id = current_setting('app.current_vet_id', true)::INT
    AND EXISTS (
        SELECT 1
        FROM vet_atiende_mascota vam
        WHERE vam.mascota_id = vacunas_aplicadas.mascota_id
          AND vam.vet_id = current_setting('app.current_vet_id', true)::INT
    )
);
