REVOKE ALL ON DATABASE clinica_vet FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

CREATE ROLE role_vet NOLOGIN;
CREATE ROLE role_recepcion NOLOGIN;
CREATE ROLE role_admin NOLOGIN;

CREATE ROLE app_vet LOGIN PASSWORD :'vet_pwd' IN ROLE role_vet;
CREATE ROLE app_recepcion LOGIN PASSWORD :'recep_pwd' IN ROLE role_recepcion;
CREATE ROLE app_admin LOGIN PASSWORD :'admin_pwd' IN ROLE role_admin;

GRANT CONNECT ON DATABASE clinica_vet TO role_vet, role_recepcion, role_admin;
GRANT USAGE ON SCHEMA public TO role_vet, role_recepcion, role_admin;

GRANT SELECT ON mascotas TO role_vet, role_recepcion, role_admin;

GRANT SELECT ON duenos TO role_vet, role_recepcion, role_admin;

GRANT SELECT ON veterinarios TO role_recepcion, role_admin;

GRANT SELECT, INSERT, UPDATE ON citas TO role_vet, role_recepcion, role_admin;

GRANT SELECT, INSERT ON vacunas_aplicadas TO role_vet, role_admin;

GRANT SELECT ON inventario_vacunas TO role_vet;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventario_vacunas TO role_admin;

GRANT SELECT ON vet_atiende_mascota TO role_vet;
GRANT SELECT, INSERT, UPDATE, DELETE ON vet_atiende_mascota TO role_admin;

GRANT SELECT, INSERT, UPDATE, DELETE ON historial_movimientos TO role_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON alertas TO role_admin;

GRANT SELECT ON v_mascotas_vacunacion_pendiente TO role_vet, role_recepcion, role_admin;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO role_vet, role_recepcion, role_admin;

GRANT EXECUTE ON PROCEDURE sp_agendar_cita(INT, INT, TIMESTAMP, TEXT) TO role_vet, role_recepcion, role_admin;
GRANT EXECUTE ON FUNCTION fn_total_facturado(INT, INT) TO role_admin;