'use client';

import { useEffect, useState } from 'react';
import { loadRole } from '../lib/role';

export default function RoleStatus() {
  const [role, setRole] = useState<string | null>(null);
  const [vetId, setVetId] = useState<number | null>(null);

  useEffect(() => {
    const data = loadRole();
    setRole(data.role);
    setVetId(data.vetId);
  }, []);

  if (!role) {
    return <span className="badge">Sin rol</span>;
  }

  return (
    <span className="badge">
      Rol: {role} {role === 'vet' && vetId ? `(vet_id ${vetId})` : ''}
    </span>
  );
}
