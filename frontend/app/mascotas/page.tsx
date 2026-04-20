'use client';

import { type FormEvent, useEffect, useState } from 'react';
import { API_BASE } from '../lib/api';
import { loadRole } from '../lib/role';
import RoleStatus from '../components/RoleStatus';

type Mascota = {
  id: number;
  nombre: string;
  especie: string;
  dueno_nombre?: string;
  telefono?: string;
};

export default function MascotasPage() {
  const [role, setRole] = useState<string | null>(null);
  const [vetId, setVetId] = useState<number | null>(null);
  const [q, setQ] = useState('');
  const [data, setData] = useState<Mascota[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    const ctx = loadRole();
    setRole(ctx.role);
    setVetId(ctx.vetId);
  }, []);

  async function handleSearch(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    if (!role) {
      setError('Selecciona rol en /login');
      return;
    }

    const url = new URL(`${API_BASE}/mascotas`);
    if (q) url.searchParams.set('q', q);

    const res = await fetch(url.toString(), {
      headers: {
        'x-role': role,
        ...(role === 'vet' && vetId ? { 'x-vet-id': String(vetId) } : {})
      }
    });

    if (!res.ok) {
      setError('No se pudo consultar');
      return;
    }

    const json = await res.json();
    setData(json.data || []);
  }

  return (
    <section className="card shell-panel">
      <div className="panel-head">
        <div>
          <span className="badge">Paso 2</span>
          <h1>Busqueda de mascotas</h1>
          <p>Panel de prueba para RLS y defensa contra SQL injection.</p>
        </div>
        <RoleStatus />
      </div>

      <form onSubmit={handleSearch} className="search-bar">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Texto libre para probar SQLi"
        />
        <button type="submit">Buscar</button>
      </form>

      {error && <p className="inline-msg">{error}</p>}

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Nombre</th>
              <th>Especie</th>
              <th>Dueno</th>
              <th>Telefono</th>
            </tr>
          </thead>
          <tbody>
            {data.map((m) => (
              <tr key={m.id}>
                <td>{m.id}</td>
                <td>{m.nombre}</td>
                <td>{m.especie}</td>
                <td>{m.dueno_nombre || '-'}</td>
                <td>{m.telefono || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
