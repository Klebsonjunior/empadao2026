import { supabase } from './supabase';

const knownHosts = {
  'empadao2026.vercel.app': 'empadao',
  'brigadeirogourmet.vercel.app': 'brigadeiros',
  localhost: null,
};

export function currentHostname() {
  return window.location.hostname.toLowerCase();
}

export async function resolveTenant() {
  const hostname = currentHostname();
  const knownSlug = knownHosts[hostname];

  let query = supabase
    .from('company_domains')
    .select('hostname, company_id, companies(id, slug, name)')
    .eq('hostname', hostname)
    .maybeSingle();

  const { data, error } = await query;
  if (!error && data?.companies) return data.companies;

  if (error?.code === '42P01' || error?.code === 'PGRST205') {
    return { slug: knownSlug, name: knownSlug === 'empadao' ? 'Empadão' : knownSlug === 'brigadeiros' ? 'Brigadeiros' : null, pendingMigration: true };
  }

  if (!error && !data) {
    return { slug: null, name: null, error: 'Este domínio não está associado à empresa da sua conta.' };
  }

  return { slug: null, name: null, error: error?.message || 'Domínio não associado a uma empresa.' };
}

export async function loadMembership(userId) {
  const { data, error } = await supabase
    .from('company_memberships')
    .select('company_id, role, companies(id, slug, name)')
    .eq('user_id', userId)
    .order('created_at', { ascending: true })
    .limit(10);

  if (error) return { data: [], error };
  return { data: data || [], error: null };
}
