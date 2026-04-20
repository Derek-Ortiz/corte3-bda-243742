export default function HomePage() {
  return (
    <div style={{ display: 'grid', gap: 16 }}>
      <section className="hero card">
        <div className="hero-copy">
          <span className="badge">PostgreSQL + Redis + Next.js</span>
          <h1>Clinica Veterinaria</h1>
          <p>
            Panel para probar roles, RLS, SQLi y cache con un flujo mas claro
            para login, busqueda, citas y vacunacion.
          </p>
        </div>
        <div className="hero-grid">
          <div className="hero-metric">
            <strong>3</strong>
            <span>roles de operacion</span>
          </div>
          <div className="hero-metric">
            <strong>RLS</strong>
            <span>sobre mascotas, citas y vacunas</span>
          </div>
          <div className="hero-metric">
            <strong>Redis</strong>
            <span>cache de vacunacion pendiente</span>
          </div>
        </div>
      </section>

      <section className="card">
        <h2>Entradas principales</h2>
        <div className="row">
          <a className="badge" href="/login">
            Login y rol
          </a>
          <a className="badge" href="/mascotas">
            Busqueda de mascotas
          </a>
          <a className="badge" href="/vacunacion">
            Vacunacion pendiente + registro
          </a>
        </div>
      </section>

      <section className="card soft">
        <h2>Que puedes probar</h2>
        <div className="two-col">
          <p>
            Cambia entre vet, recepcion y admin para ver como la misma interfaz
            retorna conjuntos de datos distintos segun permisos y RLS.
          </p>
          <p>
            Usa el buscador para meter payloads de prueba y la pantalla de
            vacunacion para ver cache hit/miss y registrar una cita nueva.
          </p>
        </div>
      </section>
    </div>
  );
}
