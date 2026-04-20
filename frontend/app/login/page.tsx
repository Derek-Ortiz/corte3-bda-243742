'use client';

import { type FormEvent, useState } from 'react';
import { saveRole } from '../lib/role';

export default function LoginPage() {
  const [role, setRole] = useState('vet');
  const [vetId, setVetId] = useState('1');
  const [msg, setMsg] = useState('');

  function handleSave(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (role === 'vet' && !vetId) {
      setMsg('vet_id requerido para rol vet');
      return;
    }
    saveRole(role as 'vet' | 'recepcion' | 'admin', Number(vetId));
    setMsg('Rol guardado. Ya puedes probar las otras pantallas.');
  }

  return (
    <section className="card auth-panel">
      <div className="auth-copy">
        <span className="badge">Paso 1</span>
        <h1>Seleccion de rol</h1>
        <p>
          Guarda el contexto de trabajo antes de abrir las otras pantallas. El
          rol vet necesita su vet_id para que RLS filtre correctamente.
        </p>
      </div>

      <form onSubmit={handleSave} className="stack-form">
        <label>
          Rol
          <select value={role} onChange={(e) => setRole(e.target.value)}>
            <option value="vet">vet</option>
            <option value="recepcion">recepcion</option>
            <option value="admin">admin</option>
          </select>
        </label>
        {role === 'vet' && (
          <label>
            vet_id
            <input
              value={vetId}
              onChange={(e) => setVetId(e.target.value)}
              placeholder="1"
            />
          </label>
        )}
        <button type="submit">Guardar rol</button>
        {msg && <p className="inline-msg">{msg}</p>}
      </form>
    </section>
  );
}
