'use client';

import { type FormEvent, useEffect, useState } from 'react';
import { API_BASE } from '../lib/api';
import { loadRole } from '../lib/role';
import RoleStatus from '../components/RoleStatus';

type VacunacionPendiente = {
  mascota_id: number;
  mascota_nombre: string;
  especie: string;
  dueno_nombre: string;
  telefono: string | null;
  vacuna_id: number;
  vacuna_nombre: string;
};

export default function VacunacionPage() {
  const [role, setRole] = useState<string | null>(null);
  const [vetId, setVetId] = useState<number | null>(null);
  const [data, setData] = useState<VacunacionPendiente[]>([]);
  const [cache, setCache] = useState('');
  const [error, setError] = useState('');

  const [mascotaId, setMascotaId] = useState('1');
  const [vacunaId, setVacunaId] = useState('1');
  const [costo, setCosto] = useState('0');
  const [adminVetId, setAdminVetId] = useState('');
  const [citaMascotaId, setCitaMascotaId] = useState('1');
  const [citaVetId, setCitaVetId] = useState('1');
  const [citaFecha, setCitaFecha] = useState('2026-04-30T10:00');
  const [citaMotivo, setCitaMotivo] = useState('Revision general');
  const [citaMsg, setCitaMsg] = useState('');

  useEffect(() => {
    const ctx = loadRole();
    setRole(ctx.role);
    setVetId(ctx.vetId);
  }, []);

  async function fetchPendientes() {
    setError('');
    if (!role) {
      setError('Selecciona rol en /login');
      return;
    }

    const res = await fetch(`${API_BASE}/vacunacion-pendiente`, {
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
    setCache(json.cache || '');
  }

  async function aplicarVacuna(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    if (!role) {
      setError('Selecciona rol en /login');
      return;
    }

    const body: Record<string, unknown> = {
      mascota_id: mascotaId,
      vacuna_id: vacunaId,
      costo_cobrado: costo
    };

    if (role === 'admin') {
      body.veterinario_id = adminVetId;
    }

    const res = await fetch(`${API_BASE}/vacunas/aplicar`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-role': role,
        ...(role === 'vet' && vetId ? { 'x-vet-id': String(vetId) } : {})
      },
      body: JSON.stringify(body)
    });

    if (!res.ok) {
      setError('No se pudo aplicar');
      return;
    }

    await fetchPendientes();
  }

  async function agendarCita(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError('');
    setCitaMsg('');
    if (!role) {
      setError('Selecciona rol en /login');
      return;
    }

    const body: Record<string, unknown> = {
      mascota_id: citaMascotaId,
      fecha_hora: citaFecha,
      motivo: citaMotivo
    };

    if (role === 'admin' || role === 'recepcion') {
      body.veterinario_id = citaVetId;
    }

    const res = await fetch(`${API_BASE}/citas/agendar`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-role': role,
        ...(role === 'vet' && vetId ? { 'x-vet-id': String(vetId) } : {})
      },
      body: JSON.stringify(body)
    });

    if (!res.ok) {
      setError('No se pudo agendar la cita');
      return;
    }

    setCitaMsg('Cita agendada correctamente');
  }

  return (
    <section className="card shell-panel">
      <div className="panel-head">
        <div>
          <span className="badge">Paso 3</span>
          <h1>Vacunacion pendiente</h1>
          <p>Consulta cacheada y formularios para registrar vacuna y cita.</p>
        </div>
        <div className="row compact">
          <RoleStatus />
          {cache && <span className="badge">Cache: {cache}</span>}
        </div>
      </div>

      <div className="toolbar">
        <button onClick={fetchPendientes} className="secondary" type="button">
          Actualizar
        </button>
      </div>

      <div className="form-grid">
        <form onSubmit={aplicarVacuna} className="stack-form card inner-card">
          <h2>Aplicar vacuna</h2>
          <input
            value={mascotaId}
            onChange={(e) => setMascotaId(e.target.value)}
            placeholder="mascota_id"
          />
          <input
            value={vacunaId}
            onChange={(e) => setVacunaId(e.target.value)}
            placeholder="vacuna_id"
          />
          <input
            value={costo}
            onChange={(e) => setCosto(e.target.value)}
            placeholder="costo"
          />
          {role === 'admin' && (
            <input
              value={adminVetId}
              onChange={(e) => setAdminVetId(e.target.value)}
              placeholder="veterinario_id"
            />
          )}
          <button type="submit">Aplicar vacuna</button>
        </form>

        <form onSubmit={agendarCita} className="stack-form card inner-card">
          <h2>Registrar cita</h2>
          <input
            value={citaMascotaId}
            onChange={(e) => setCitaMascotaId(e.target.value)}
            placeholder="mascota_id"
          />
          {(role === 'admin' || role === 'recepcion') && (
            <input
              value={citaVetId}
              onChange={(e) => setCitaVetId(e.target.value)}
              placeholder="veterinario_id"
            />
          )}
          <input
            value={citaFecha}
            onChange={(e) => setCitaFecha(e.target.value)}
            type="datetime-local"
          />
          <input
            value={citaMotivo}
            onChange={(e) => setCitaMotivo(e.target.value)}
            placeholder="motivo"
          />
          <button type="submit">Agendar cita</button>
        </form>
      </div>

      {error && <p className="inline-msg">{error}</p>}
      {citaMsg && <p className="inline-msg success">{citaMsg}</p>}

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Mascota</th>
              <th>Especie</th>
              <th>Dueno</th>
              <th>Vacuna pendiente</th>
            </tr>
          </thead>
          <tbody>
            {data.map((row) => (
              <tr key={`${row.mascota_id}-${row.vacuna_id}`}>
                <td>{row.mascota_nombre}</td>
                <td>{row.especie}</td>
                <td>{row.dueno_nombre}</td>
                <td>{row.vacuna_nombre}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
