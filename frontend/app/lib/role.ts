export type Role = 'vet' | 'recepcion' | 'admin';

export const ROLE_KEY = 'bda_role';
export const VET_ID_KEY = 'bda_vet_id';

export function saveRole(role: Role, vetId?: number) {
  localStorage.setItem(ROLE_KEY, role);
  if (role === 'vet' && vetId) {
    localStorage.setItem(VET_ID_KEY, String(vetId));
  } else {
    localStorage.removeItem(VET_ID_KEY);
  }
}

export function loadRole(): { role: Role | null; vetId: number | null } {
  const roleRaw = localStorage.getItem(ROLE_KEY);
  const role = roleRaw === 'vet' || roleRaw === 'recepcion' || roleRaw === 'admin'
    ? roleRaw
    : null;
  const vetRaw = localStorage.getItem(VET_ID_KEY);
  const vetId = vetRaw ? Number(vetRaw) : null;
  return { role, vetId };
}
