import { useEffect, useMemo, useState } from 'react';
import { supabase } from './lib/supabase';
import { loadMembership, resolveTenant } from './lib/tenant';
import './styles.css';

const modules = [
  ['dashboard', 'Dashboard'],
  ['sales', 'Vendas'],
  ['production', 'Produção'],
  ['inventory', 'Estoque'],
  ['products', 'Produtos'],
  ['recipes', 'Fichas técnicas'],
  ['ingredients', 'Ingredientes'],
  ['purchases', 'Compras'],
  ['reports', 'Relatórios'],
];

const tables = {
  ingredients: 'Ingredientes',
  products: 'Produtos',
  purchases: 'Compras',
  purchase_batches: 'Lotes de compras',
  production_batches: 'Produções',
  sales: 'Vendas',
  inventory_movements: 'Movimentos de estoque',
};

function formatBRL(value) {
  return Number(value || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function AuthScreen({ onAuthenticated }) {
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    setMessage('');
    const result = mode === 'login'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password });
    if (result.error) setMessage(result.error.message);
    else if (mode === 'signup') setMessage('Conta criada. Confirme o e-mail se o projeto exigir confirmação.');
    else onAuthenticated(result.data.session);
    setBusy(false);
  }

  return <main className="auth-page">
    <section className="auth-card">
      <div className="brand-mark">🥧</div>
      <h1>Controle Empadões</h1>
      <p className="muted">Gestão partilhada por empresa</p>
      <form onSubmit={submit}>
        <label>E-mail<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required autoComplete="username" /></label>
        <label>Senha<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} required minLength={6} autoComplete={mode === 'login' ? 'current-password' : 'new-password'} /></label>
        {message && <p className="form-message">{message}</p>}
        <button className="primary-button" disabled={busy}>{busy ? 'Aguarde…' : mode === 'login' ? 'Entrar' : 'Criar conta'}</button>
      </form>
      <button className="link-button" onClick={() => { setMode(mode === 'login' ? 'signup' : 'login'); setMessage(''); }}>
        {mode === 'login' ? 'Ainda não tem conta? Criar conta' : 'Já tem conta? Entrar'}
      </button>
    </section>
  </main>;
}

function App() {
  const [session, setSession] = useState(null);
  const [tenant, setTenant] = useState(null);
  const [membership, setMembership] = useState(null);
  const [metrics, setMetrics] = useState({});
  const [activeModule, setActiveModule] = useState('dashboard');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function loadContext(currentSession) {
    setLoading(true);
    setError('');
    const [tenantResult, membershipResult] = await Promise.all([
      resolveTenant(),
      loadMembership(currentSession.user.id),
    ]);
    if (membershipResult.error && !['42P01', 'PGRST205'].includes(membershipResult.error.code)) {
      setError(membershipResult.error.message);
    }
    const matching = membershipResult.data.find((entry) => entry.companies?.slug === tenantResult.slug);
    setTenant(tenantResult);
    setMembership(matching || membershipResult.data[0] || null);

    const nextMetrics = {};
    await Promise.all(Object.keys(tables).map(async (table) => {
      const { count, error: countError } = await supabase.from(table).select('*', { count: 'exact', head: true });
      if (!countError) nextMetrics[table] = count || 0;
    }));
    setMetrics(nextMetrics);
    setLoading(false);
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (data.session) loadContext(data.session);
      else setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      if (nextSession) loadContext(nextSession);
      else setTenant(null);
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  const totalRecords = useMemo(() => Object.values(metrics).reduce((sum, value) => sum + value, 0), [metrics]);

  if (loading && !session) return <div className="loading-screen">A carregar o sistema…</div>;
  if (!session) return <AuthScreen onAuthenticated={setSession} />;

  async function logout() {
    await supabase.auth.signOut();
    setSession(null);
  }

  return <div className="app-shell">
    <header className="topbar">
      <div><div className="eyebrow">{tenant?.name || 'Empresa'}</div><h1>Controle Empadões</h1></div>
      <div className="account"><span>{session.user.email}</span><button onClick={logout}>Sair</button></div>
    </header>
    <div className="workspace">
      <aside className="sidebar">
        <div className="tenant-card"><span className="status-dot" />{tenant?.name || 'Empresa não resolvida'}<small>{membership?.role === 'administrator' ? 'Administrador' : 'Utilizador'}</small></div>
        <nav>{modules.map(([id, label]) => <button className={activeModule === id ? 'active' : ''} key={id} onClick={() => setActiveModule(id)}>{label}</button>)}</nav>
        <a className="legacy-link" href="/legacy/index.legacy.html">Abrir versão legada</a>
      </aside>
      <main className="content">
        {tenant?.pendingMigration && <div className="notice warning">A base multiempresa ainda não foi aplicada. O acesso continuará limitado até a migration ser confirmada.</div>}
        {error && <div className="notice error">{error}</div>}
        <div className="content-heading"><div><p className="eyebrow">{activeModule === 'dashboard' ? 'Visão geral' : activeModule}</p><h2>{activeModule === 'dashboard' ? 'Operação da empresa' : modules.find(([id]) => id === activeModule)?.[1]}</h2></div><span className="date-chip">{new Date().toLocaleDateString('pt-BR')}</span></div>
        {activeModule === 'dashboard' ? <>
          <section className="metrics-grid">
            <Metric label="Produtos" value={metrics.products} />
            <Metric label="Ingredientes" value={metrics.ingredients} />
            <Metric label="Compras" value={metrics.purchases} />
            <Metric label="Vendas" value={metrics.sales} />
          </section>
          <section className="panel hero-panel"><div><p className="eyebrow">Dados partilhados</p><h3>Uma empresa, várias contas individuais.</h3><p className="muted">Todos os utilizadores associados a {tenant?.name || 'esta empresa'} verão o mesmo estoque, compras, vendas e produção quando o RLS multiempresa estiver ativo.</p></div><div className="hero-stat"><strong>{totalRecords}</strong><span>registos carregados</span></div></section>
        </> : <DataModule module={activeModule} />}
      </main>
    </div>
  </div>;
}

function DataModule({ module }) {
  const configs = {
    sales: { table: 'sales', title: 'Vendas', columns: [['sale_date', 'Data'], ['total', 'Total'], ['cost', 'Custo'], ['profit', 'Lucro']] },
    production: { table: 'production_batches', title: 'Produção', columns: [['production_date', 'Data'], ['qty_produced', 'Produzido'], ['qty_lost', 'Perdas'], ['unit_cost', 'Custo unitário']] },
    inventory: { table: 'inventory_movements', title: 'Estoque', columns: [['movement_date', 'Data'], ['item_type', 'Tipo'], ['movement_type', 'Movimento'], ['qty_change', 'Variação']] },
    products: { table: 'products', title: 'Produtos', columns: [['name', 'Nome'], ['price', 'Preço'], ['stock', 'Estoque'], ['active', 'Ativo']] },
    recipes: { table: 'recipes', title: 'Fichas técnicas', columns: [['product_id', 'Produto'], ['yield_qty', 'Rendimento'], ['created_at', 'Criada em']] },
    ingredients: { table: 'ingredients', title: 'Ingredientes', columns: [['name', 'Nome'], ['family', 'Família'], ['unit', 'Unidade'], ['stock', 'Estoque']] },
    purchases: { table: 'purchases', title: 'Compras', columns: [['purchase_date', 'Data'], ['qty', 'Quantidade'], ['unit', 'Unidade'], ['total_cost', 'Custo total']] },
    reports: { table: 'sales', title: 'Relatórios', columns: [['sale_date', 'Data'], ['total', 'Vendas'], ['cost', 'Custos'], ['profit', 'Lucro']] },
  };
  const config = configs[module] || configs.products;
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError('');
    supabase.from(config.table).select(config.columns.map(([key]) => key).join(',')).order(config.columns[0][0], { ascending: false }).limit(100)
      .then(({ data, error: queryError }) => {
        if (!active) return;
        if (queryError) setError(queryError.message);
        setRows(data || []);
        setLoading(false);
      });
    return () => { active = false; };
  }, [config.table]);

  return <section className="panel data-panel">
    <div className="panel-heading"><div><p className="eyebrow">Dados da empresa</p><h3>{config.title}</h3></div><span className="row-count">{loading ? 'A carregar…' : `${rows.length} registos`}</span></div>
    {error && <div className="notice error">{error}</div>}
    {loading ? <p className="muted">A carregar dados partilhados…</p> : rows.length === 0 ? <div className="empty-state"><p className="muted">Ainda não há registos neste módulo para a empresa atual.</p><a className="secondary-button" href="/legacy/index.html">Abrir operações no legado</a></div> : <div className="table-wrap"><table><thead><tr>{config.columns.map(([, label]) => <th key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={row.id || index}>{config.columns.map(([key]) => <td key={key}>{formatCell(row[key], key)}</td>)}</tr>)}</tbody></table></div>}
  </section>;
}

function formatCell(value, key) {
  if (value === null || value === undefined) return '—';
  if (key.includes('cost') || key === 'total' || key === 'price' || key === 'profit' || key === 'unit_cost') return formatBRL(value);
  if (key === 'active') return value ? 'Sim' : 'Não';
  if (key.includes('date') || key === 'created_at') return new Date(value).toLocaleDateString('pt-BR');
  if (typeof value === 'number') return value.toLocaleString('pt-BR');
  return String(value);
}

function Metric({ label, value }) {
  return <div className="metric-card"><span>{label}</span><strong>{value ?? '—'}</strong><small>empresa atual</small></div>;
}

export default App;
