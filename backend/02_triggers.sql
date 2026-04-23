
CREATE OR REPLACE FUNCTION fn_historial_cita()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO historial_movimientos (tipo, referencia_id, descripcion)
    VALUES (
        'CITA',
        NEW.id,
        'Cita creada para mascota ' || NEW.mascota_id ||
        ' con veterinario ' || NEW.veterinario_id
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_cita ON citas;

CREATE TRIGGER trg_historial_cita
AFTER INSERT ON citas
FOR EACH ROW
EXECUTE FUNCTION fn_historial_cita();
