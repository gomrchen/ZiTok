import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import {
  ConfigProvider,
  Form,
  Input,
  Button,
  Table,
  Space,
  Modal,
  InputNumber,
  Select,
  message,
  Tag,
  Upload,
  Divider,
  Popconfirm,
} from 'antd'
import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { UploadFile } from 'antd/es/upload/interface'
import {
  createDrama,
  createEpisode,
  uploadEpisode,
  fetchStats,
  listDramas,
  listEpisodes,
  login,
  offlineDrama,
  onlineDrama,
  updateDrama,
  updateEpisode,
  deleteEpisode,
  adjustWallet,
  getWallet,
  listLedger,
  listUnlocks,
  searchUsers,
  listUsers,
  getUserDetail,
  adminTopup,
  listTopups,
  listTopDramas,
  batchEpisodePricing,
  uploadCover,
  deleteDrama,
  restoreDrama,
  batchDramaStatus,
  batchRestoreDramas,
  batchPurgeDramas,
  purgeDrama,
  listCategories,
  listCategoryStats,
  createCategory,
  renameCategory,
  deleteCategory,
  getDramaDetail,
  reorderEpisode,
  grantUnlock,
  revokeUnlock,
  changePassword,
  type Drama,
  type Episode,
  type AdminStats,
  type LedgerItem,
  type UnlockItem,
  type UserBrief,
  type UserDetail,
  type DramaOpsStat,
  type EpisodeOpsStat,
  type CategoryStat,
} from './api'
import './App.css'

const navGroups = [
  {
    title: '工作台',
    items: [{ key: 'stats', label: '数据大盘', desc: '指标与流水' }],
  },
  {
    title: '内容库',
    items: [
      { key: 'dramas', label: '剧目管理', desc: '分集与定价' },
      { key: 'categories', label: '分类管理', desc: '归类重命名' },
      { key: 'top', label: '热门榜', desc: '播放与收入' },
      { key: 'trash', label: '回收站', desc: '恢复与清理' },
    ],
  },
  {
    title: '营收',
    items: [
      { key: 'unlocks', label: '解锁流水', desc: '查询与赠退' },
      { key: 'topups', label: '充值记录', desc: '入账查询' },
      { key: 'ledger', label: '金币流水', desc: '账变明细' },
      { key: 'wallet', label: '调账充值', desc: '补偿补发' },
    ],
  },
  {
    title: '用户中心',
    items: [{ key: 'users', label: '用户列表', desc: '检索与操作' }],
  },
  {
    title: '系统',
    items: [{ key: 'account', label: '账号设置', desc: '资料改密' }],
  },
] as const

type NavKey = (typeof navGroups)[number]['items'][number]['key']

const pageMeta: Record<NavKey, { group: string; title: string; blurb: string }> = {
  stats: { group: '工作台', title: '数据大盘', blurb: '全站指标与近期流水' },
  dramas: { group: '内容库', title: '剧目管理', blurb: '剧目、分集、封面与定价' },
  categories: { group: '内容库', title: '分类管理', blurb: '题材统计与重命名' },
  top: { group: '内容库', title: '热门榜', blurb: '按播放或收入排序' },
  trash: { group: '内容库', title: '回收站', blurb: '恢复或永久删除' },
  unlocks: { group: '营收', title: '解锁流水', blurb: '查询、赠送与撤销' },
  topups: { group: '营收', title: '充值记录', blurb: '入账查询与补币' },
  ledger: { group: '营收', title: '金币流水', blurb: '账变明细查询' },
  wallet: { group: '营收', title: '调账充值', blurb: '补偿与活动补发' },
  users: { group: '用户中心', title: '用户列表', blurb: '检索与调账' },
  account: { group: '系统', title: '账号设置', blurb: '资料与改密' },
}

function fmtTime(v?: string) {
  return v ? String(v).replace('T', ' ').slice(0, 19) : '-'
}

function PageFrame({ children }: { children: ReactNode }) {
  return <div className="page-enter">{children}</div>
}

function LoginView({ onOk }: { onOk: () => void }) {
  const [loading, setLoading] = useState(false)
  return (
    <div className="login-page">
      <section className="login-visual">
        <h1 className="login-visual-brand">ZiTok</h1>
        <p className="login-visual-copy">短剧运营后台。剧目、解锁、充值与用户数据在此处理。</p>
      </section>
      <section className="login-side">
        <div className="login-box">
          <h2>登录</h2>
          <p className="hint">使用运营账号进入。本地默认 admin / admin123。</p>
          <Form
            layout="vertical"
            requiredMark={false}
            initialValues={{ username: 'admin', password: 'admin123' }}
            onFinish={async (v) => {
              setLoading(true)
              try {
                const data = await login(v.username, v.password)
                localStorage.setItem('admin_token', data.token)
                localStorage.setItem('admin_username', data.admin?.username || v.username)
                localStorage.setItem('admin_id', String(data.admin?.id ?? ''))
                message.success('登录成功')
                onOk()
              } catch (e: any) {
                message.error(e.message || '登录失败')
              } finally {
                setLoading(false)
              }
            }}
          >
            <Form.Item name="username" label="账号" rules={[{ required: true, message: '请输入账号' }]}>
              <Input size="large" autoComplete="username" />
            </Form.Item>
            <Form.Item name="password" label="密码" rules={[{ required: true, message: '请输入密码' }]}>
              <Input.Password size="large" autoComplete="current-password" />
            </Form.Item>
            <Button type="primary" htmlType="submit" block loading={loading}>
              登录
            </Button>
          </Form>
          <p className="login-meta">内部系统 · 请勿转发账号</p>
        </div>
      </section>
    </div>
  )
}

function useCountUp(target: number, duration = 700) {
  const [n, setN] = useState(0)
  useEffect(() => {
    let raf = 0
    const start = performance.now()
    const from = 0
    const tick = (t: number) => {
      const p = Math.min(1, (t - start) / duration)
      const eased = 1 - Math.pow(1 - p, 3)
      setN(Math.round(from + (target - from) * eased))
      if (p < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, duration])
  return n
}

function AnimValue({ value }: { value: number }) {
  const n = useCountUp(Number(value) || 0)
  return <>{n.toLocaleString()}</>
}

const UNLOCK_TYPE_LABEL: Record<number, string> = { 1: '单集', 2: '整剧', 3: '广告' }
const DONUT_COLORS = ['#3d7eff', '#69a1ff', '#9ec2ff', '#c5d8f5']

function StatsPanel() {
  const [stats, setStats] = useState<AdminStats>({
    drama_count: 0,
    online_count: 0,
    episode_count: 0,
    unlock_count: 0,
    play_sum: 0,
    user_count: 0,
    coin_sum: 0,
    top_dramas: [],
    unlock_types: [],
    daily_revenue: [],
    recent_unlocks: [],
    recent_topups: [],
  })
  useEffect(() => {
    fetchStats().then(setStats).catch(() => {})
  }, [])

  const hero = [
    { label: '今日收入', value: stats.today_revenue ?? 0, note: '当日解锁金币' },
    { label: '解锁次数', value: stats.unlock_count, note: '累计付费/广告' },
    { label: '在线剧目', value: stats.online_count, note: '当前可播' },
    { label: '注册用户', value: stats.user_count, note: '注册总量' },
  ]
  const secondary = [
    { label: '剧目总数', value: stats.drama_count },
    { label: '分集总数', value: stats.episode_count },
    { label: '解锁收入', value: stats.unlock_revenue ?? 0 },
    { label: '今日解锁', value: stats.today_unlocks ?? 0 },
    { label: '今日充值', value: stats.today_topup_amt ?? 0 },
    { label: '广告解锁', value: stats.ad_unlock_count ?? 0 },
    { label: '播放量', value: stats.play_sum },
    { label: '金币池', value: stats.coin_sum },
  ]
  const tops = stats.top_dramas || []
  const trend = (stats.daily_revenue || []).map((d) => ({
    date: d.date.slice(5),
    revenue: Number(d.revenue) || 0,
    count: Number(d.count) || 0,
  }))
  const signupTrend = (stats.daily_signups || []).map((d) => ({
    date: d.date.slice(5),
    count: Number(d.count) || 0,
  }))
  const topupTrend = (stats.daily_topups || []).map((d) => ({
    date: d.date.slice(5),
    revenue: Number(d.revenue) || 0,
    count: Number(d.count) || 0,
  }))
  const pieData = (stats.unlock_types || []).map((t) => ({
    name: UNLOCK_TYPE_LABEL[t.unlock_type] || `类型${t.unlock_type}`,
    value: Number(t.count) || 0,
    revenue: Number(t.revenue) || 0,
  }))
  const typeLabel = (t: number) => UNLOCK_TYPE_LABEL[t] || String(t)

  return (
    <div className="stack board-a">
      <div className="kpi-row kpi-hero">
        {hero.map((it) => (
          <div key={it.label} className="kpi kpi-lg">
            <div className="label">{it.label}</div>
            <div className="value">
              <AnimValue value={it.value} />
            </div>
            <div className="note">{it.note}</div>
          </div>
        ))}
      </div>

      <div className="stats-banner stats-banner-compact">
        <div className="stats-banner-badges">
          {secondary.map((it) => (
            <span key={it.label} className="chip">
              {it.label} <b>{Number(it.value || 0).toLocaleString()}</b>
            </span>
          ))}
        </div>
      </div>

      <div className="block">
        <div className="block-hd">
          <div>
            <h2>近7日收入趋势</h2>
            <p>按日汇总解锁金币收入</p>
          </div>
        </div>
        <div className="block-bd chart-bd">
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={trend} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="revFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#3d7eff" stopOpacity={0.28} />
                  <stop offset="100%" stopColor="#3d7eff" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#eef0f3" vertical={false} />
              <XAxis dataKey="date" tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} width={40} />
              <Tooltip
                contentStyle={{ borderRadius: 6, border: '1px solid #e5e6eb', fontSize: 12 }}
                formatter={(v) => [Number(v ?? 0).toLocaleString(), '收入']}
              />
              <Area type="monotone" dataKey="revenue" stroke="#3d7eff" strokeWidth={2.5} fill="url(#revFill)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="split-2">
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>近7日注册</h2>
              <p>日新增用户</p>
            </div>
          </div>
          <div className="block-bd chart-bd">
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={signupTrend} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="signupFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#1a9f6e" stopOpacity={0.28} />
                    <stop offset="100%" stopColor="#1a9f6e" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#eef0f3" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} width={36} />
                <Tooltip
                  contentStyle={{ borderRadius: 6, border: '1px solid #e5e6eb', fontSize: 12 }}
                  formatter={(v) => [Number(v ?? 0).toLocaleString(), '注册']}
                />
                <Area type="monotone" dataKey="count" stroke="#1a9f6e" strokeWidth={2} fill="url(#signupFill)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>近7日充值</h2>
              <p>日充值金币额</p>
            </div>
          </div>
          <div className="block-bd chart-bd">
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={topupTrend} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="topupFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#e6a23c" stopOpacity={0.28} />
                    <stop offset="100%" stopColor="#e6a23c" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#eef0f3" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#8a8f99', fontSize: 12 }} axisLine={false} tickLine={false} width={40} />
                <Tooltip
                  contentStyle={{ borderRadius: 6, border: '1px solid #e5e6eb', fontSize: 12 }}
                  formatter={(v) => [Number(v ?? 0).toLocaleString(), '充值']}
                />
                <Area type="monotone" dataKey="revenue" stroke="#e6a23c" strokeWidth={2} fill="url(#topupFill)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="split-2">
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>热门剧 TOP5</h2>
              <p>按播放量排序</p>
            </div>
          </div>
          <div className="block-bd">
            <Table
              rowKey="id"
              size="small"
              pagination={false}
              dataSource={tops}
              columns={[
                { title: 'ID', dataIndex: 'id', width: 64 },
                { title: '剧名', dataIndex: 'title' },
                {
                  title: '播放',
                  dataIndex: 'play_count',
                  width: 100,
                  render: (v) => Number(v || 0).toLocaleString(),
                },
              ]}
            />
          </div>
        </div>
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>解锁构成</h2>
              <p>按类型汇总次数与收入</p>
            </div>
          </div>
          <div className="block-bd chart-bd donut-wrap">
            {pieData.length === 0 ? (
              <div className="hint">暂无解锁数据</div>
            ) : (
              <>
                <ResponsiveContainer width="100%" height={200}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      dataKey="value"
                      nameKey="name"
                      innerRadius={58}
                      outerRadius={82}
                      paddingAngle={2}
                    >
                      {pieData.map((_, i) => (
                        <Cell key={i} fill={DONUT_COLORS[i % DONUT_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{ borderRadius: 6, border: '1px solid #e5e6eb', fontSize: 12 }}
                      formatter={(v, _n, item) => {
                        const rev = (item?.payload as { revenue?: number } | undefined)?.revenue ?? 0
                        return [`${Number(v ?? 0)} 次 · 收入 ${Number(rev).toLocaleString()}`, '构成']
                      }}
                    />
                  </PieChart>
                </ResponsiveContainer>
                <div className="donut-legend">
                  {pieData.map((it, i) => (
                    <span key={it.name} className="donut-legend-item">
                      <i style={{ background: DONUT_COLORS[i % DONUT_COLORS.length] }} />
                      {it.name}
                      <b>{it.value}</b>
                    </span>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      <div className="split-2">
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>最近解锁</h2>
            </div>
          </div>
          <div className="block-bd">
            <Table
              rowKey="id"
              size="small"
              pagination={false}
              dataSource={stats.recent_unlocks || []}
              columns={[
                {
                  title: '用户',
                  width: 100,
                  render: (_, r) => r.username || r.user_id,
                },
                {
                  title: '剧',
                  ellipsis: true,
                  render: (_, r) => r.drama_title || r.drama_id,
                },
                { title: '类型', dataIndex: 'unlock_type', width: 70, render: typeLabel },
                { title: '价', dataIndex: 'price', width: 60 },
                { title: '时间', dataIndex: 'created_at', render: (v) => fmtTime(v) },
              ]}
            />
          </div>
        </div>
        <div className="block">
          <div className="block-hd">
            <div>
              <h2>最近充值</h2>
            </div>
          </div>
          <div className="block-bd">
            <Table
              rowKey="id"
              size="small"
              pagination={false}
              dataSource={stats.recent_topups || []}
              columns={[
                { title: '用户', dataIndex: 'user_id', width: 70 },
                {
                  title: '金额',
                  dataIndex: 'change_amount',
                  width: 80,
                  render: (v) => <span style={{ color: '#1a9f6e' }}>+{v}</span>,
                },
                { title: '时间', dataIndex: 'created_at', render: (v) => fmtTime(v) },
              ]}
            />
          </div>
        </div>
      </div>
    </div>
  )
}

function DramaPanel({ fixedStatus }: { fixedStatus?: string }) {
  const [list, setList] = useState<Drama[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(false)
  const [q, setQ] = useState('')
  const [status, setStatus] = useState(fixedStatus || 'all')
  const [category, setCategory] = useState<string | undefined>()
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState<Drama | null>(null)
  const [epOpen, setEpOpen] = useState(false)
  const [current, setCurrent] = useState<Drama | null>(null)
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [epEdit, setEpEdit] = useState<Episode | null>(null)
  const [priceOpen, setPriceOpen] = useState(false)
  const [createCover, setCreateCover] = useState('')
  const [editCover, setEditCover] = useState('')
  const [categories, setCategories] = useState<string[]>(['甜宠', '古装', '青春'])
  const [selectedIds, setSelectedIds] = useState<number[]>([])
  const [detailOpen, setDetailOpen] = useState(false)
  const [detailStats, setDetailStats] = useState<DramaOpsStat | null>(null)
  const [episodeStats, setEpisodeStats] = useState<EpisodeOpsStat[]>([])
  const [page, setPage] = useState(1)
  const [sort, setSort] = useState('updated')
  const pageSize = 20

  const effectiveStatus = fixedStatus || status

  const reload = useCallback(async () => {
    setLoading(true)
    try {
      const data = await listDramas({
        q,
        status: effectiveStatus,
        category,
        page,
        size: pageSize,
        sort: sort === 'updated' ? undefined : sort,
      })
      setList(data.list || [])
      setTotal(data.total || 0)
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }, [q, effectiveStatus, category, page, sort])

  useEffect(() => {
    let alive = true
    setLoading(true)
    listDramas({
      q,
      status: effectiveStatus,
      category,
      page,
      size: pageSize,
      sort: sort === 'updated' ? undefined : sort,
    })
      .then((data) => {
        if (!alive) return
        setList(data.list || [])
        setTotal(data.total || 0)
      })
      .catch((e: any) => {
        if (alive) message.error(e.message)
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
    }
  }, [q, effectiveStatus, category, page, sort])

  useEffect(() => {
    listCategories()
      .then((cats) => {
        if (cats.length) setCategories(cats)
      })
      .catch(() => {})
  }, [])

  const openEpisodes = async (row: Drama) => {
    setCurrent(row)
    setEpisodes(await listEpisodes(row.id))
    setEpOpen(true)
  }

  const openDetail = async (row: Drama) => {
    setCurrent(row)
    try {
      const data = await getDramaDetail(row.id)
      setDetailStats(data.stats)
      setEpisodes(data.episodes || [])
      setEpisodeStats(data.episode_stats || [])
      setDetailOpen(true)
    } catch (e: any) {
      message.error(e.message)
    }
  }

  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>{fixedStatus === 'deleted' ? '回收站' : '剧目列表'}</h2>
          <p>
            {loading && list.length === 0
              ? '加载中…'
              : `共 ${total} 部 · ${
                  fixedStatus === 'deleted' ? '已软删剧目，可恢复后重新上架' : '支持搜索、筛选、编辑与分集维护'
                }`}
          </p>
        </div>
        {fixedStatus === 'deleted' ? (
          <Space>
            {selectedIds.length > 0 && (
              <>
                <Button
                  type="primary"
                  onClick={async () => {
                    const res = await batchRestoreDramas(selectedIds)
                    message.success(`已恢复 ${res.updated} 部`)
                    setSelectedIds([])
                    reload()
                  }}
                >
                  批量恢复
                </Button>
                <Popconfirm
                  title="永久删除选中剧目？不可恢复"
                  onConfirm={async () => {
                    const res = await batchPurgeDramas(selectedIds)
                    message.success(`已永久删除 ${res.deleted} 部`)
                    setSelectedIds([])
                    reload()
                  }}
                >
                  <Button danger>批量永久删除</Button>
                </Popconfirm>
              </>
            )}
          </Space>
        ) : (
          <Space>
            {selectedIds.length > 0 && (
              <>
                <Button
                  onClick={async () => {
                    await batchDramaStatus(selectedIds, 1)
                    message.success(`已上架 ${selectedIds.length} 部`)
                    setSelectedIds([])
                    reload()
                  }}
                >
                  批量上架
                </Button>
                <Button
                  onClick={async () => {
                    await batchDramaStatus(selectedIds, 2)
                    message.success(`已下架 ${selectedIds.length} 部`)
                    setSelectedIds([])
                    reload()
                  }}
                >
                  批量下架
                </Button>
              </>
            )}
            <Button type="primary" onClick={() => setOpen(true)}>
              新建剧目
            </Button>
          </Space>
        )}
      </div>
      <div className="block-bd">
        <div className="toolbar">
          <Input.Search
            className="grow"
            allowClear
            placeholder="搜剧名 / 简介 / 标签"
            onSearch={(v) => {
              setPage(1)
              setQ(v.trim())
            }}
            onChange={(e) => {
              if (!e.target.value) {
                setPage(1)
                setQ('')
              }
            }}
          />
          {fixedStatus === 'deleted' ? null : (
            <Select
              style={{ width: 120 }}
              value={status}
              onChange={(v) => {
                setPage(1)
                setStatus(v)
              }}
              options={[
                { value: 'all', label: '全部状态' },
                { value: '1', label: '上架' },
                { value: '2', label: '下架' },
              ]}
            />
          )}
          <Select
            allowClear
            style={{ width: 120 }}
            placeholder="分类"
            value={category}
            onChange={(v) => {
              setPage(1)
              setCategory(v)
            }}
            options={categories.map((c) => ({ value: c, label: c }))}
          />
          <Select
            style={{ width: 130 }}
            value={sort}
            onChange={(v) => {
              setPage(1)
              setSort(v)
            }}
            options={[
              { value: 'updated', label: '最近更新' },
              { value: 'play_desc', label: '播放高→低' },
              { value: 'revenue_desc', label: '收入高→低' },
              { value: 'created_desc', label: '最新创建' },
              { value: 'id_asc', label: 'ID 升序' },
            ]}
          />
          <Button onClick={reload}>刷新</Button>
        </div>
        <Table
          rowKey="id"
          loading={loading}
          dataSource={list}
          rowSelection={{
            selectedRowKeys: selectedIds,
            onChange: (keys) => setSelectedIds(keys as number[]),
          }}
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: false,
            onChange: setPage,
          }}
          columns={[
            { title: 'ID', dataIndex: 'id', width: 64 },
            { title: '剧名', dataIndex: 'title' },
            { title: '分类', dataIndex: 'category', width: 80 },
            { title: '集数', dataIndex: 'total_episodes', width: 64 },
            {
              title: '播放',
              dataIndex: 'play_count',
              width: 88,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            {
              title: '收入',
              dataIndex: 'unlock_revenue',
              width: 88,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            {
              title: '状态',
              dataIndex: 'status',
              width: 80,
              render: (v) =>
                status === 'deleted' || fixedStatus === 'deleted' ? (
                  <Tag color="default">已删</Tag>
                ) : v === 1 ? (
                  <Tag color="success">上架</Tag>
                ) : (
                  <Tag>下架</Tag>
                ),
            },
            {
              title: '操作',
              width: 420,
              render: (_, row) =>
                status === 'deleted' || fixedStatus === 'deleted' ? (
                  <Space size={6}>
                    <Button
                      size="small"
                      type="primary"
                      onClick={async () => {
                        await restoreDrama(row.id)
                        message.success('已恢复（默认下架）')
                        reload()
                      }}
                    >
                      恢复
                    </Button>
                    <Popconfirm
                      title="永久删除？不可恢复"
                      onConfirm={async () => {
                        await purgeDrama(row.id)
                        message.success('已永久删除')
                        reload()
                      }}
                    >
                      <Button size="small" danger>
                        永久删
                      </Button>
                    </Popconfirm>
                  </Space>
                ) : (
                  <Space size={6} wrap>
                    <Button size="small" onClick={() => openDetail(row)}>
                      详情
                    </Button>
                    <Button size="small" onClick={() => openEpisodes(row)}>
                      分集
                    </Button>
                    <Button
                      size="small"
                      onClick={() => {
                        setEditing(row)
                        setEditCover(row.cover_url || '')
                        setEditOpen(true)
                      }}
                    >
                      编辑
                    </Button>
                    <Button
                      size="small"
                      onClick={() => {
                        setCurrent(row)
                        setPriceOpen(true)
                      }}
                    >
                      定价
                    </Button>
                    {row.status === 1 ? (
                      <Button
                        size="small"
                        danger
                        onClick={async () => {
                          await offlineDrama(row.id)
                          message.success('已下架')
                          reload()
                        }}
                      >
                        下架
                      </Button>
                    ) : (
                      <Button
                        size="small"
                        type="primary"
                        onClick={async () => {
                          await onlineDrama(row.id)
                          message.success('已上架')
                          reload()
                        }}
                      >
                        上架
                      </Button>
                    )}
                    <Popconfirm
                      title="软删除该剧目？可恢复"
                      onConfirm={async () => {
                        await deleteDrama(row.id)
                        message.success('已删除')
                        reload()
                      }}
                    >
                      <Button size="small" danger>
                        删
                      </Button>
                    </Popconfirm>
                  </Space>
                ),
            },
          ]}
        />
      </div>

      <Modal
        title="新建剧目"
        open={open}
        onCancel={() => {
          setOpen(false)
          setCreateCover('')
        }}
        footer={null}
        destroyOnHidden
      >
        <Form
          layout="vertical"
          initialValues={{ category: '甜宠', free_episode_count: 3, bundle_price: 80, status: 1 }}
          onFinish={async (v) => {
            await createDrama({ ...v, cover_url: createCover || v.cover_url })
            message.success('创建成功')
            setOpen(false)
            setCreateCover('')
            reload()
          }}
        >
          <Form.Item name="title" label="剧名" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <div className="field-block">
            <label>封面</label>
            <Input
              placeholder="/covers/xxx.jpg"
              value={createCover}
              onChange={(e) => setCreateCover(e.target.value)}
            />
            <Upload
              accept="image/*"
              maxCount={1}
              showUploadList={false}
              beforeUpload={async (file) => {
                try {
                  const res = await uploadCover(file)
                  setCreateCover(res.cover_url)
                  message.success('封面已上传')
                } catch (e: any) {
                  message.error(e.message || '上传失败')
                }
                return false
              }}
            >
              <Button style={{ marginTop: 8 }}>上传封面图</Button>
            </Upload>
            {createCover ? (
              <div className="cover-preview">
                <img src={createCover} alt="cover" />
                <span>{createCover}</span>
              </div>
            ) : null}
          </div>
          <Form.Item name="description" label="简介">
            <Input.TextArea rows={3} />
          </Form.Item>
          <Form.Item name="tags" label="标签">
            <Input placeholder="逗号分隔，如：重生,虐恋" />
          </Form.Item>
          <Form.Item name="category" label="分类">
            <Select
              options={categories.map((c) => ({ value: c, label: c }))}
              dropdownRender={(menu) => menu}
              showSearch
            />
          </Form.Item>
          <Form.Item name="free_episode_count" label="免费集数">
            <InputNumber min={0} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="bundle_price" label="整剧金币价">
            <InputNumber min={0} style={{ width: '100%' }} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block>
            保存
          </Button>
        </Form>
      </Modal>

      <Modal
        title={editing ? `编辑 · ${editing.title}` : '编辑剧目'}
        open={editOpen}
        onCancel={() => {
          setEditOpen(false)
          setEditCover('')
        }}
        footer={null}
        destroyOnHidden
      >
        {editing && (
          <Form
            layout="vertical"
            initialValues={editing}
            onFinish={async (v) => {
              await updateDrama(editing.id, { ...editing, ...v, cover_url: editCover || v.cover_url })
              message.success('已保存')
              setEditOpen(false)
              setEditCover('')
              reload()
            }}
          >
            <Form.Item name="title" label="剧名" rules={[{ required: true }]}>
              <Input />
            </Form.Item>
            <div className="field-block">
              <label>封面</label>
              <Input value={editCover} onChange={(e) => setEditCover(e.target.value)} />
              <Upload
                accept="image/*"
                maxCount={1}
                showUploadList={false}
                beforeUpload={async (file) => {
                  try {
                    const res = await uploadCover(file, editing.id)
                    setEditCover(res.cover_url)
                    message.success('封面已更新')
                  } catch (e: any) {
                    message.error(e.message || '上传失败')
                  }
                  return false
                }}
              >
                <Button style={{ marginTop: 8 }}>上传并绑定封面</Button>
              </Upload>
              {editCover ? (
                <div className="cover-preview">
                  <img src={editCover} alt="cover" />
                  <span>{editCover}</span>
                </div>
              ) : null}
            </div>
            <Form.Item name="description" label="简介">
              <Input.TextArea rows={3} />
            </Form.Item>
            <Form.Item name="tags" label="标签">
              <Input />
            </Form.Item>
            <Form.Item name="category" label="分类">
              <Select options={categories.map((c) => ({ value: c, label: c }))} showSearch />
            </Form.Item>
            <Form.Item name="free_episode_count" label="免费集数">
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="bundle_price" label="整剧金币价">
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Button type="primary" htmlType="submit" block>
              保存修改
            </Button>
          </Form>
        )}
      </Modal>

      <Modal
        title={current ? `分集管理 · ${current.title}` : '分集管理'}
        open={epOpen}
        onCancel={() => setEpOpen(false)}
        width={860}
        footer={null}
      >
        <div className="toolbar" style={{ marginBottom: 12 }}>
          <Button
            onClick={() => {
              setPriceOpen(true)
            }}
          >
            批量定价
          </Button>
        </div>
        <Table
          size="small"
          rowKey="id"
          dataSource={episodes}
          pagination={false}
          columns={[
            { title: '集', dataIndex: 'episode_no', width: 56 },
            { title: '标题', dataIndex: 'title' },
            { title: '免费', dataIndex: 'is_free', width: 64, render: (v) => (v ? '是' : '否') },
            { title: '价格', dataIndex: 'unlock_price', width: 72 },
            { title: '视频', dataIndex: 'video_url', ellipsis: true },
            {
              title: '操作',
              width: 200,
              render: (_, row) => (
                <Space size={6}>
                  <Button size="small" onClick={() => setEpEdit(row)}>
                    改
                  </Button>
                  <Button
                    size="small"
                    onClick={async () => {
                      const no = window.prompt('调整集号为', String(row.episode_no))
                      if (!no) return
                      const n = Number(no)
                      if (!n || n < 1) {
                        message.error('集号无效')
                        return
                      }
                      await reorderEpisode(row.id, n)
                      message.success('集号已调整')
                      if (current) setEpisodes(await listEpisodes(current.id))
                    }}
                  >
                    调序
                  </Button>
                  <Popconfirm
                    title="删除该分集？"
                    onConfirm={async () => {
                      await deleteEpisode(row.id)
                      message.success('已删除')
                      if (current) setEpisodes(await listEpisodes(current.id))
                      reload()
                    }}
                  >
                    <Button size="small" danger>
                      删
                    </Button>
                  </Popconfirm>
                </Space>
              ),
            },
          ]}
        />

        <Divider orientationMargin={0}>用 URL 添加</Divider>
        <Form
          layout="inline"
          onFinish={async (v) => {
            if (!current) return
            await createEpisode(current.id, {
              episode_no: v.episode_no,
              title: v.title || `第${v.episode_no}集`,
              video_url: v.video_url,
              is_free: !!v.is_free,
              unlock_price: v.unlock_price ?? 10,
            })
            message.success('已添加分集')
            setEpisodes(await listEpisodes(current.id))
            reload()
          }}
        >
          <Form.Item name="episode_no" rules={[{ required: true }]}>
            <InputNumber placeholder="集号" min={1} />
          </Form.Item>
          <Form.Item name="title">
            <Input placeholder="标题" />
          </Form.Item>
          <Form.Item name="video_url" rules={[{ required: true }]}>
            <Input placeholder="视频 URL" style={{ width: 220 }} />
          </Form.Item>
          <Form.Item name="unlock_price" initialValue={10}>
            <InputNumber placeholder="价格" min={0} />
          </Form.Item>
          <Form.Item name="is_free">
            <Select
              allowClear
              placeholder="是否免费"
              style={{ width: 100 }}
              options={[
                { value: true, label: '免费' },
                { value: false, label: '付费' },
              ]}
            />
          </Form.Item>
          <Button type="primary" htmlType="submit">
            添加
          </Button>
        </Form>

        <Divider orientationMargin={0}>本地上传视频</Divider>
        <Form
          layout="inline"
          onFinish={async (v) => {
            if (!current) return
            const fileList = (v.file as UploadFile[] | undefined) || []
            const raw = fileList[0]?.originFileObj
            if (!raw) {
              message.error('请选择视频文件')
              return
            }
            await uploadEpisode(current.id, raw as File, {
              episode_no: v.episode_no,
              title: v.title,
              is_free: !!v.is_free,
              unlock_price: v.unlock_price ?? 10,
            })
            message.success('上传成功')
            setEpisodes(await listEpisodes(current.id))
            reload()
          }}
        >
          <Form.Item name="episode_no">
            <InputNumber placeholder="集号(可空)" min={1} />
          </Form.Item>
          <Form.Item name="title">
            <Input placeholder="标题" />
          </Form.Item>
          <Form.Item name="unlock_price" initialValue={10}>
            <InputNumber placeholder="价格" min={0} />
          </Form.Item>
          <Form.Item name="is_free" initialValue={false}>
            <Select
              style={{ width: 100 }}
              options={[
                { value: true, label: '免费' },
                { value: false, label: '付费' },
              ]}
            />
          </Form.Item>
          <Form.Item
            name="file"
            valuePropName="fileList"
            getValueFromEvent={(e) => (Array.isArray(e) ? e : e?.fileList)}
            rules={[{ required: true, message: '选择文件' }]}
          >
            <Upload beforeUpload={() => false} maxCount={1} accept="video/*">
              <Button>选择文件</Button>
            </Upload>
          </Form.Item>
          <Button type="primary" htmlType="submit">
            上传
          </Button>
        </Form>
      </Modal>

      <Modal
        title={epEdit ? `编辑分集 · 第${epEdit.episode_no}集` : '编辑分集'}
        open={!!epEdit}
        onCancel={() => setEpEdit(null)}
        footer={null}
        destroyOnHidden
      >
        {epEdit && (
          <Form
            layout="vertical"
            initialValues={epEdit}
            onFinish={async (v) => {
              await updateEpisode(epEdit.id, { ...epEdit, ...v })
              message.success('分集已更新')
              setEpEdit(null)
              if (current) setEpisodes(await listEpisodes(current.id))
            }}
          >
            <Form.Item name="episode_no" label="集号">
              <InputNumber min={1} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="title" label="标题">
              <Input />
            </Form.Item>
            <Form.Item name="video_url" label="视频 URL">
              <Input />
            </Form.Item>
            <Form.Item name="unlock_price" label="解锁价格">
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="is_free" label="是否免费">
              <Select
                options={[
                  { value: true, label: '免费' },
                  { value: false, label: '付费' },
                ]}
              />
            </Form.Item>
            <Button type="primary" htmlType="submit" block>
              保存
            </Button>
          </Form>
        )}
      </Modal>

      <Modal
        title={current ? `剧目详情 · ${current.title}` : '剧目详情'}
        open={detailOpen}
        onCancel={() => setDetailOpen(false)}
        width={900}
        footer={null}
        destroyOnHidden
      >
        {detailStats && (
          <div className="kpi-row" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))', marginBottom: 16 }}>
            {[
              { label: '播放', value: detailStats.play_count },
              { label: '分集', value: detailStats.episode_count },
              { label: '解锁次数', value: detailStats.unlock_count },
              { label: '解锁收入', value: detailStats.unlock_revenue },
              { label: '在追', value: detailStats.watching_count },
              { label: '收藏', value: detailStats.fav_count },
            ].map((it) => (
              <div key={it.label} className="kpi">
                <div className="label">{it.label}</div>
                <div className="value">{Number(it.value || 0).toLocaleString()}</div>
              </div>
            ))}
          </div>
        )}
        <Table
          size="small"
          rowKey="id"
          pagination={false}
          scroll={{ x: 760 }}
          dataSource={(episodeStats.length ? episodeStats : episodes) as EpisodeOpsStat[]}
          columns={[
            { title: '集', dataIndex: 'episode_no', width: 56 },
            { title: '标题', dataIndex: 'title', ellipsis: true },
            { title: '免费', dataIndex: 'is_free', width: 56, render: (v: boolean) => (v ? '是' : '否') },
            { title: '价格', dataIndex: 'unlock_price', width: 64 },
            {
              title: '播放',
              dataIndex: 'visit_count',
              width: 80,
              render: (v?: number) => Number(v || 0).toLocaleString(),
            },
            {
              title: '时长',
              dataIndex: 'duration',
              width: 72,
              render: (v?: number) => (v ? `${Math.round(Number(v) / 60)}′` : '—'),
            },
            {
              title: '解锁',
              dataIndex: 'unlock_count',
              width: 72,
              render: (v?: number) => (v == null ? '—' : Number(v).toLocaleString()),
            },
            {
              title: '集收入',
              dataIndex: 'unlock_revenue',
              width: 88,
              render: (v?: number) => (v == null ? '—' : Number(v).toLocaleString()),
            },
          ]}
        />
      </Modal>

      <Modal
        title={current ? `批量定价 · ${current.title}` : '批量定价'}
        open={priceOpen}
        onCancel={() => setPriceOpen(false)}
        footer={null}
        destroyOnHidden
      >
        {current && (
          <Form
            layout="vertical"
            initialValues={{
              free_count: current.free_episode_count ?? 3,
              unlock_price: 10,
            }}
            onFinish={async (v) => {
              const res = await batchEpisodePricing(current.id, v.free_count, v.unlock_price)
              message.success(`已更新 ${res.updated} 集`)
              setPriceOpen(false)
              if (epOpen) setEpisodes(await listEpisodes(current.id))
              reload()
            }}
          >
            <p className="hint" style={{ marginBottom: 12 }}>
              前 N 集设为免费，其余统一解锁价。会同步改剧目免费集数字段。
            </p>
            <Form.Item name="free_count" label="免费集数" rules={[{ required: true }]}>
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="unlock_price" label="付费集解锁价" rules={[{ required: true }]}>
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Button type="primary" htmlType="submit" block>
              应用定价
            </Button>
          </Form>
        )}
      </Modal>
    </div>
  )
}

function UnlocksPanel() {
  const [list, setList] = useState<UnlockItem[]>([])
  const [loading, setLoading] = useState(false)
  const [userId, setUserId] = useState<number | null>(null)
  const [dramaId, setDramaId] = useState<number | null>(null)
  const [unlockType, setUnlockType] = useState<number | null>(null)
  const [expiredOnly, setExpiredOnly] = useState(false)
  const [grantOpen, setGrantOpen] = useState(false)
  const reload = async (
    uid = userId,
    did = dramaId,
    ut = unlockType,
    expired = expiredOnly,
  ) => {
    setLoading(true)
    try {
      setList(
        await listUnlocks({
          limit: 80,
          user_id: uid || undefined,
          drama_id: did || undefined,
          unlock_type: ut || undefined,
          expired_only: expired,
        }),
      )
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
  }, [])
  const typeLabel = (t: number) => ({ 1: '单集', 2: '整剧', 3: '广告' }[t] || String(t))
  return (
    <div className="stack">
      <div className="block">
        <div className="block-hd">
          <div>
            <h2>解锁流水</h2>
            <p>富化用户/剧名 · 过期筛选 · 赠送与退币撤销</p>
          </div>
          <Space>
            <Button onClick={() => setGrantOpen(true)}>赠送解锁</Button>
            <Button onClick={() => reload()}>刷新</Button>
          </Space>
        </div>
        <div className="block-bd">
          <div className="toolbar">
            <InputNumber
              placeholder="用户 ID"
              value={userId ?? undefined}
              onChange={(v) => setUserId(typeof v === 'number' ? v : null)}
              style={{ width: 140 }}
            />
            <InputNumber
              placeholder="剧目 ID"
              value={dramaId ?? undefined}
              onChange={(v) => setDramaId(typeof v === 'number' ? v : null)}
              style={{ width: 140 }}
            />
            <Select
              allowClear
              placeholder="解锁类型"
              style={{ width: 120 }}
              value={unlockType ?? undefined}
              onChange={(v) => setUnlockType(typeof v === 'number' ? v : null)}
              options={[
                { value: 1, label: '单集' },
                { value: 2, label: '整剧' },
                { value: 3, label: '广告' },
              ]}
            />
            <Select
              style={{ width: 120 }}
              value={expiredOnly ? '1' : '0'}
              onChange={(v) => setExpiredOnly(v === '1')}
              options={[
                { value: '0', label: '全部' },
                { value: '1', label: '仅过期' },
              ]}
            />
            <Button type="primary" onClick={() => reload()}>
              筛选
            </Button>
            <Button
              onClick={async () => {
                setUserId(null)
                setDramaId(null)
                setUnlockType(null)
                setExpiredOnly(false)
                await reload(null, null, null, false)
              }}
            >
              清空
            </Button>
          </div>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={list}
            pagination={{ pageSize: 12 }}
            scroll={{ x: 980 }}
            columns={[
              { title: 'ID', dataIndex: 'id', width: 70 },
              {
                title: '用户',
                width: 110,
                render: (_, r) => r.username || r.user_id,
              },
              {
                title: '剧',
                width: 140,
                ellipsis: true,
                render: (_, r) => r.drama_title || r.drama_id,
              },
              { title: '集', dataIndex: 'episode_id', width: 70 },
              { title: '类型', dataIndex: 'unlock_type', width: 70, render: typeLabel },
              { title: '价格', dataIndex: 'price', width: 70 },
              {
                title: '状态',
                width: 72,
                render: (_, r) =>
                  r.expired ? <Tag color="default">过期</Tag> : <Tag color="success">有效</Tag>,
              },
              {
                title: '到期',
                dataIndex: 'expire_at',
                width: 140,
                render: (v) => (v ? fmtTime(v) : '—'),
              },
              {
                title: '时间',
                dataIndex: 'created_at',
                width: 140,
                render: (v) => fmtTime(v),
              },
              {
                title: '操作',
                width: 160,
                fixed: 'right',
                render: (_, row) => (
                  <Space size={6}>
                    <Popconfirm
                      title="撤销该解锁？"
                      onConfirm={async () => {
                        await revokeUnlock(row.id, false)
                        message.success('已撤销')
                        reload()
                      }}
                    >
                      <Button size="small">撤销</Button>
                    </Popconfirm>
                    <Popconfirm
                      title="撤销并退回金币？"
                      onConfirm={async () => {
                        await revokeUnlock(row.id, true)
                        message.success('已撤销并退币')
                        reload()
                      }}
                    >
                      <Button size="small" danger>
                        退币撤销
                      </Button>
                    </Popconfirm>
                  </Space>
                ),
              },
            ]}
          />
        </div>
      </div>

      <Modal title="赠送解锁" open={grantOpen} onCancel={() => setGrantOpen(false)} footer={null} destroyOnHidden>
        <Form
          layout="vertical"
          initialValues={{ unlock_type: 1 }}
          onFinish={async (v) => {
            await grantUnlock({
              user_id: v.user_id,
              drama_id: v.drama_id,
              episode_id: v.unlock_type === 2 ? 0 : v.episode_id,
              unlock_type: v.unlock_type,
            })
            message.success('已赠送')
            setGrantOpen(false)
            reload(v.user_id, v.drama_id)
          }}
        >
          <Form.Item name="user_id" label="用户 ID" rules={[{ required: true }]}>
            <InputNumber style={{ width: '100%' }} min={1} />
          </Form.Item>
          <Form.Item name="drama_id" label="剧目 ID" rules={[{ required: true }]}>
            <InputNumber style={{ width: '100%' }} min={1} />
          </Form.Item>
          <Form.Item name="unlock_type" label="类型" rules={[{ required: true }]}>
            <Select
              options={[
                { value: 1, label: '单集' },
                { value: 2, label: '整剧' },
                { value: 3, label: '广告(24h)' },
              ]}
            />
          </Form.Item>
          <Form.Item name="episode_id" label="分集 ID（整剧可空）">
            <InputNumber style={{ width: '100%' }} min={0} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block>
            确认赠送
          </Button>
        </Form>
      </Modal>
    </div>
  )
}

function UsersPanel() {
  const [q, setQ] = useState('')
  const [sort, setSort] = useState('id_desc')
  const [list, setList] = useState<UserBrief[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [detail, setDetail] = useState<UserDetail | null>(null)

  const reload = useCallback(async () => {
    setLoading(true)
    try {
      const data = await listUsers({
        q,
        page,
        size: 15,
        sort: sort === 'id_desc' ? undefined : sort,
      })
      setList(data.list || [])
      setTotal(data.total || 0)
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }, [q, page, sort])

  useEffect(() => {
    let alive = true
    setLoading(true)
    listUsers({
      q,
      page,
      size: 15,
      sort: sort === 'id_desc' ? undefined : sort,
    })
      .then((data) => {
        if (!alive) return
        setList(data.list || [])
        setTotal(data.total || 0)
      })
      .catch((e: any) => {
        if (alive) message.error(e.message)
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
    }
  }, [q, page, sort])

  const openDetail = async (id: number) => {
    try {
      setDetail(await getUserDetail(id))
    } catch (e: any) {
      message.error(e.message)
    }
  }

  return (
    <div className="split-2">
      <div className="block">
        <div className="block-hd">
          <div>
            <h2>用户列表</h2>
            <p>{loading && list.length === 0 ? '加载中…' : `共 ${total} 人 · 支持排序与快捷调账`}</p>
          </div>
          <Button onClick={reload}>刷新</Button>
        </div>
        <div className="block-bd">
          <div className="toolbar">
            <Input.Search
              className="grow"
              placeholder="用户 ID 或用户名"
              onSearch={(v) => {
                setPage(1)
                setQ(v.trim())
              }}
              allowClear
              onChange={(e) => {
                if (!e.target.value) {
                  setQ('')
                  setPage(1)
                }
              }}
            />
            <Select
              style={{ width: 140 }}
              value={sort}
              onChange={(v) => {
                setPage(1)
                setSort(v)
              }}
              options={[
                { value: 'id_desc', label: '最新注册' },
                { value: 'id_asc', label: '最早注册' },
                { value: 'balance_desc', label: '余额高→低' },
                { value: 'balance_asc', label: '余额低→高' },
              ]}
            />
          </div>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={list}
            pagination={{
              current: page,
              pageSize: 15,
              total,
              onChange: setPage,
              showSizeChanger: false,
            }}
            columns={[
              { title: 'ID', dataIndex: 'id', width: 80 },
              { title: '用户名', dataIndex: 'username' },
              {
                title: '余额',
                dataIndex: 'balance',
                width: 90,
                render: (v) => <span className="bal">{v}</span>,
              },
              {
                title: '操作',
                width: 200,
                render: (_, row) => (
                  <Space size={6}>
                    <Button size="small" onClick={() => openDetail(row.id)}>
                      详情
                    </Button>
                    <Button
                      size="small"
                      onClick={async () => {
                        const amt = window.prompt('充值金币数', '100')
                        if (!amt) return
                        const n = Number(amt)
                        if (!n || n < 1) return message.error('金额无效')
                        const res = await adminTopup(row.id, n)
                        message.success(`充值成功，余额 ${res.balance}`)
                        reload()
                        if (detail?.user_id === row.id) openDetail(row.id)
                      }}
                    >
                      充值
                    </Button>
                    <Button
                      size="small"
                      onClick={async () => {
                        const delta = window.prompt('调账变动（正加负减）', '10')
                        if (!delta) return
                        const n = Number(delta)
                        if (!n) return message.error('变动无效')
                        const res = await adjustWallet(row.id, n, 'admin_quick')
                        message.success(`调账成功，余额 ${res.balance}`)
                        reload()
                        if (detail?.user_id === row.id) openDetail(row.id)
                      }}
                    >
                      调账
                    </Button>
                  </Space>
                ),
              },
            ]}
          />
        </div>
      </div>
      <div className="block">
        <div className="block-hd">
          <div>
            <h2>用户画像</h2>
            <p>{detail ? `用户 #${detail.user_id} · 余额 ${detail.balance}` : '从左侧选择用户'}</p>
          </div>
        </div>
        <div className="block-bd">
          {!detail ? (
            <p className="hint">点击「详情」查看在追、收藏与解锁</p>
          ) : (
            <>
              {detail.summary?.username ? (
                <p className="hint" style={{ marginBottom: 10 }}>
                  {detail.summary.username}
                  {detail.summary.created_at ? ` · 注册 ${fmtTime(detail.summary.created_at)}` : ''}
                  {detail.summary.last_watch_at ? ` · 最近观看 ${fmtTime(detail.summary.last_watch_at)}` : ''}
                </p>
              ) : null}
              <div className="kpi-row" style={{ gridTemplateColumns: 'repeat(3, 1fr)', marginBottom: 12 }}>
                <div className="kpi">
                  <div className="label">余额</div>
                  <div className="value">{detail.balance}</div>
                </div>
                <div className="kpi">
                  <div className="label">累计充值</div>
                  <div className="value">{detail.summary?.topup_sum ?? 0}</div>
                </div>
                <div className="kpi">
                  <div className="label">累计消费</div>
                  <div className="value">{detail.summary?.spend_sum ?? 0}</div>
                </div>
                <div className="kpi">
                  <div className="label">解锁次数</div>
                  <div className="value">{detail.summary?.unlock_count ?? detail.unlocks?.length ?? 0}</div>
                </div>
                <div className="kpi">
                  <div className="label">收藏</div>
                  <div className="value">{detail.fav_count}</div>
                </div>
                <div className="kpi">
                  <div className="label">在追</div>
                  <div className="value">{detail.watch_count}</div>
                </div>
              </div>
              <Divider orientationMargin={0}>在追</Divider>
              <Table
                size="small"
                rowKey="id"
                pagination={false}
                dataSource={detail.watching || []}
                locale={{ emptyText: '暂无' }}
                columns={[
                  { title: '剧', dataIndex: 'drama_id', width: 70 },
                  { title: '集', dataIndex: 'episode_no', width: 56 },
                  { title: '进度', dataIndex: 'position_sec', width: 72 },
                ]}
              />
              <Divider orientationMargin={0}>收藏</Divider>
              <Table
                size="small"
                rowKey="id"
                pagination={false}
                dataSource={detail.favorites || []}
                locale={{ emptyText: '暂无' }}
                columns={[
                  { title: 'ID', dataIndex: 'id', width: 70 },
                  { title: '剧名', dataIndex: 'title' },
                ]}
              />
              <Divider orientationMargin={0}>解锁</Divider>
              <Table
                size="small"
                rowKey="id"
                pagination={false}
                dataSource={detail.unlocks || []}
                locale={{ emptyText: '暂无' }}
                columns={[
                  {
                    title: '剧',
                    ellipsis: true,
                    render: (_, r) => r.drama_title || r.drama_id,
                  },
                  { title: '集', dataIndex: 'episode_id', width: 56 },
                  { title: '价', dataIndex: 'price', width: 56 },
                  {
                    title: '状态',
                    width: 64,
                    render: (_, r) => (r.expired ? '过期' : '有效'),
                  },
                ]}
              />
              <Divider orientationMargin={0}>近期账变</Divider>
              <Table
                size="small"
                rowKey="id"
                pagination={false}
                dataSource={detail.ledger || []}
                locale={{ emptyText: '暂无' }}
                columns={[
                  {
                    title: '变动',
                    dataIndex: 'change_amount',
                    width: 72,
                    render: (v) => (
                      <span style={{ color: v >= 0 ? '#1f7a5c' : '#b42318' }}>{v > 0 ? `+${v}` : v}</span>
                    ),
                  },
                  { title: '原因', dataIndex: 'reason', ellipsis: true },
                  { title: '时间', dataIndex: 'created_at', render: (v) => fmtTime(v) },
                ]}
              />
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function WalletPanel() {
  const [q, setQ] = useState('')
  const [users, setUsers] = useState<UserBrief[]>([])
  const [selected, setSelected] = useState<UserBrief | null>(null)
  const [balance, setBalance] = useState<number | null>(null)
  const [ledger, setLedger] = useState<LedgerItem[]>([])
  const [searching, setSearching] = useState(false)

  const pickUser = async (u: UserBrief) => {
    setSelected(u)
    const w = await getWallet(u.id)
    setBalance(w.balance)
    setLedger(w.ledger || [])
  }

  const doSearch = async (keyword: string) => {
    setSearching(true)
    try {
      setUsers(await searchUsers(keyword))
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setSearching(false)
    }
  }

  const refreshSelected = async () => {
    if (!selected) return
    await pickUser(selected)
    doSearch(q || String(selected.id))
  }

  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>调账 / 充值</h2>
          <p>搜索用户后加减金币或模拟充值；全站流水见「金币流水 / 充值记录」</p>
        </div>
      </div>
      <div className="block-bd">
        <div className="toolbar">
          <Input.Search
            className="grow"
            placeholder="用户 ID 或用户名"
            enterButton="搜索"
            loading={searching}
            onSearch={(v) => doSearch(v.trim())}
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        {users.map((u) => (
          <div key={u.id} className="user-pick">
            <div>
              <strong>
                {u.username} <span>#{u.id}</span>
              </strong>
              <div>
                余额 <span className="bal">{u.balance}</span>
              </div>
            </div>
            <Button size="small" type={selected?.id === u.id ? 'primary' : 'default'} onClick={() => pickUser(u)}>
              选择
            </Button>
          </div>
        ))}

        {selected && (
          <>
            <Divider orientationMargin={0}>
              当前：{selected.username}#{selected.id}
              {balance != null ? ` · 余额 ${balance}` : ''}
            </Divider>
            <Form
              className="wallet-row"
              layout="vertical"
              onFinish={async (v) => {
                const res = await adjustWallet(selected.id, v.delta, v.reason || 'admin')
                message.success(`调账成功，余额 ${res.balance}`)
                setBalance(res.balance)
                await refreshSelected()
              }}
            >
              <Form.Item name="delta" label="变动" rules={[{ required: true }]}>
                <InputNumber placeholder="正加负减" style={{ width: 160 }} />
              </Form.Item>
              <Form.Item name="reason" label="原因">
                <Input placeholder="活动补发 / 客诉补偿" style={{ width: 220 }} />
              </Form.Item>
              <Form.Item label=" ">
                <Button type="primary" htmlType="submit">
                  提交调账
                </Button>
              </Form.Item>
            </Form>
            <Form
              className="wallet-row"
              layout="vertical"
              initialValues={{ amount: 100 }}
              onFinish={async (v) => {
                const res = await adminTopup(selected.id, v.amount)
                message.success(`充值成功，余额 ${res.balance}`)
                setBalance(res.balance)
                await refreshSelected()
              }}
            >
              <Form.Item name="amount" label="模拟充值" rules={[{ required: true }]}>
                <InputNumber min={1} placeholder="金币数" style={{ width: 160 }} />
              </Form.Item>
              <Form.Item label=" ">
                <Space>
                  <Button htmlType="submit" type="primary">
                    充值入账
                  </Button>
                </Space>
              </Form.Item>
            </Form>
            <Space style={{ marginBottom: 12 }}>
              {[50, 100, 200, 500].map((n) => (
                <Button
                  key={n}
                  size="small"
                  onClick={async () => {
                    const res = await adminTopup(selected.id, n)
                    message.success(`+${n}，余额 ${res.balance}`)
                    setBalance(res.balance)
                    await refreshSelected()
                  }}
                >
                  +{n}
                </Button>
              ))}
            </Space>
            <Table
              size="small"
              rowKey="id"
              pagination={false}
              dataSource={ledger}
              columns={[
                {
                  title: '变动',
                  dataIndex: 'change_amount',
                  width: 80,
                  render: (v) => (
                    <span style={{ color: v >= 0 ? '#1f7a5c' : '#b42318' }}>{v > 0 ? `+${v}` : v}</span>
                  ),
                },
                { title: '余额', dataIndex: 'balance_after', width: 80 },
                { title: '原因', dataIndex: 'reason' },
                { title: '时间', dataIndex: 'created_at', width: 160, render: (v) => fmtTime(v) },
              ]}
            />
          </>
        )}
      </div>
    </div>
  )
}

function TopupsPanel() {
  const [list, setList] = useState<LedgerItem[]>([])
  const [loading, setLoading] = useState(false)
  const [userId, setUserId] = useState<number | null>(null)
  const [quickOpen, setQuickOpen] = useState(false)
  const reload = async (uid = userId) => {
    setLoading(true)
    try {
      setList(await listTopups({ limit: 80, user_id: uid || undefined }))
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
  }, [])
  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>充值记录</h2>
          <p>可按用户筛选，并快捷模拟充值</p>
        </div>
        <Space>
          <Button onClick={() => setQuickOpen(true)}>快捷充值</Button>
          <Button onClick={() => reload()}>刷新</Button>
        </Space>
      </div>
      <div className="block-bd">
        <div className="toolbar">
          <InputNumber
            placeholder="用户 ID"
            value={userId ?? undefined}
            onChange={(v) => setUserId(typeof v === 'number' ? v : null)}
            style={{ width: 140 }}
          />
          <Button type="primary" onClick={() => reload()}>
            筛选
          </Button>
          <Button
            onClick={() => {
              setUserId(null)
              reload(null)
            }}
          >
            清空
          </Button>
        </div>
        <Table
          rowKey="id"
          loading={loading}
          dataSource={list}
          pagination={{ pageSize: 15 }}
          columns={[
            { title: 'ID', dataIndex: 'id', width: 70 },
            { title: '用户', dataIndex: 'user_id', width: 90 },
            {
              title: '金额',
              dataIndex: 'change_amount',
              width: 90,
              render: (v) => <span style={{ color: '#1f7a5c' }}>+{v}</span>,
            },
            { title: '余额', dataIndex: 'balance_after', width: 90 },
            { title: '原因', dataIndex: 'reason' },
            { title: '时间', dataIndex: 'created_at', render: (v) => fmtTime(v) },
          ]}
        />
      </div>
      <Modal title="快捷充值" open={quickOpen} onCancel={() => setQuickOpen(false)} footer={null} destroyOnHidden>
        <Form
          layout="vertical"
          initialValues={{ amount: 100 }}
          onFinish={async (v) => {
            const res = await adminTopup(v.user_id, v.amount)
            message.success(`充值成功，余额 ${res.balance}`)
            setQuickOpen(false)
            setUserId(v.user_id)
            reload(v.user_id)
          }}
        >
          <Form.Item name="user_id" label="用户 ID" rules={[{ required: true }]}>
            <InputNumber min={1} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="amount" label="金额" rules={[{ required: true }]}>
            <InputNumber min={1} style={{ width: '100%' }} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block>
            确认充值
          </Button>
        </Form>
      </Modal>
    </div>
  )
}

function LedgerPanel() {
  const [list, setList] = useState<LedgerItem[]>([])
  const [loading, setLoading] = useState(false)
  const [userId, setUserId] = useState<number | null>(null)
  const [reason, setReason] = useState<string | undefined>()
  const reload = async (uid = userId, r = reason) => {
    setLoading(true)
    try {
      setList(await listLedger({ limit: 100, user_id: uid || undefined, reason: r || undefined }))
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
  }, [])
  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>金币流水</h2>
          <p>按用户 / 原因筛选账变</p>
        </div>
        <Button onClick={() => reload()}>刷新</Button>
      </div>
      <div className="block-bd">
        <div className="toolbar">
          <InputNumber
            placeholder="用户 ID"
            value={userId ?? undefined}
            onChange={(v) => setUserId(typeof v === 'number' ? v : null)}
            style={{ width: 140 }}
          />
          <Select
            allowClear
            placeholder="原因"
            style={{ width: 160 }}
            value={reason}
            onChange={setReason}
            options={[
              { value: 'topup', label: '充值 topup' },
              { value: 'unlock', label: '解锁 unlock' },
              { value: 'admin', label: '调账 admin' },
              { value: 'ad_reward', label: '广告奖励' },
              { value: 'register_bonus', label: '注册赠币' },
              { value: 'unlock_refund', label: '解锁退币' },
            ]}
          />
          <Button type="primary" onClick={() => reload()}>
            筛选
          </Button>
          <Button
            onClick={() => {
              setUserId(null)
              setReason(undefined)
              reload(null, undefined)
            }}
          >
            清空
          </Button>
        </div>
        <Table
          rowKey="id"
          loading={loading}
          dataSource={list}
          pagination={{ pageSize: 15 }}
          columns={[
            { title: 'ID', dataIndex: 'id', width: 70 },
            { title: '用户', dataIndex: 'user_id', width: 90 },
            {
              title: '变动',
              dataIndex: 'change_amount',
              width: 90,
              render: (v) => (
                <span style={{ color: v >= 0 ? '#1f7a5c' : '#b42318' }}>{v > 0 ? `+${v}` : v}</span>
              ),
            },
            { title: '余额', dataIndex: 'balance_after', width: 90 },
            { title: '原因', dataIndex: 'reason', ellipsis: true },
            { title: '时间', dataIndex: 'created_at', render: (v) => fmtTime(v) },
          ]}
        />
      </div>
    </div>
  )
}

function TopDramasPanel() {
  const [list, setList] = useState<Drama[]>([])
  const [loading, setLoading] = useState(false)
  const [sort, setSort] = useState<'play' | 'revenue'>('play')
  const [selectedIds, setSelectedIds] = useState<number[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState<Drama | null>(null)
  const [categories, setCategories] = useState<string[]>([])
  const reload = async (s = sort) => {
    setLoading(true)
    try {
      setList(await listTopDramas(20, s))
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
    listCategories()
      .then((c) => {
        if (c.length) setCategories(c)
      })
      .catch(() => {})
  }, [])
  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>热门榜</h2>
          <p>播放量 / 解锁收入双榜 · 支持编辑与批量上下架</p>
        </div>
        <Space>
          {selectedIds.length > 0 && (
            <>
              <Button
                onClick={async () => {
                  await batchDramaStatus(selectedIds, 1)
                  message.success(`已上架 ${selectedIds.length} 部`)
                  setSelectedIds([])
                  reload()
                }}
              >
                批量上架
              </Button>
              <Button
                danger
                onClick={async () => {
                  await batchDramaStatus(selectedIds, 2)
                  message.success(`已下架 ${selectedIds.length} 部`)
                  setSelectedIds([])
                  reload()
                }}
              >
                批量下架
              </Button>
            </>
          )}
          <Select
            style={{ width: 140 }}
            value={sort}
            onChange={(v) => {
              setSort(v)
              reload(v)
            }}
            options={[
              { value: 'play', label: '按播放量' },
              { value: 'revenue', label: '按解锁收入' },
            ]}
          />
          <Button onClick={() => reload()}>刷新</Button>
        </Space>
      </div>
      <div className="block-bd">
        <Table
          rowKey="id"
          loading={loading}
          dataSource={list}
          pagination={false}
          rowSelection={{
            selectedRowKeys: selectedIds,
            onChange: (keys) => setSelectedIds(keys as number[]),
          }}
          columns={[
            { title: '名次', width: 64, render: (_, __, i) => i + 1 },
            { title: 'ID', dataIndex: 'id', width: 70 },
            { title: '剧名', dataIndex: 'title' },
            { title: '分类', dataIndex: 'category', width: 90 },
            {
              title: '播放',
              dataIndex: 'play_count',
              width: 100,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            {
              title: '解锁收入',
              dataIndex: 'unlock_revenue',
              width: 100,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            { title: '集数', dataIndex: 'total_episodes', width: 70 },
            {
              title: '状态',
              dataIndex: 'status',
              width: 80,
              render: (v) => (v === 1 ? <Tag color="success">上架</Tag> : <Tag>下架</Tag>),
            },
            {
              title: '操作',
              width: 200,
              render: (_, row) => (
                <Space size={6}>
                  <Button
                    size="small"
                    onClick={() => {
                      setEditing(row)
                      setEditOpen(true)
                    }}
                  >
                    编辑
                  </Button>
                  {row.status === 1 ? (
                    <Button
                      size="small"
                      danger
                      onClick={async () => {
                        await offlineDrama(row.id)
                        message.success('已下架')
                        reload()
                      }}
                    >
                      下架
                    </Button>
                  ) : (
                    <Button
                      size="small"
                      type="primary"
                      onClick={async () => {
                        await onlineDrama(row.id)
                        message.success('已上架')
                        reload()
                      }}
                    >
                      上架
                    </Button>
                  )}
                </Space>
              ),
            },
          ]}
        />
      </div>
      <Modal
        title={editing ? `编辑剧目 · ${editing.title}` : '编辑剧目'}
        open={editOpen}
        onCancel={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        footer={null}
        destroyOnHidden
      >
        {editing && (
          <Form
            layout="vertical"
            initialValues={editing}
            onFinish={async (v) => {
              await updateDrama(editing.id, {
                title: v.title,
                category: v.category,
                description: v.description,
                tags: v.tags,
                bundle_price: v.bundle_price,
                free_episode_count: v.free_episode_count,
                status: v.status,
              })
              message.success('已保存')
              setEditOpen(false)
              setEditing(null)
              reload()
            }}
          >
            <Form.Item name="title" label="剧名" rules={[{ required: true }]}>
              <Input />
            </Form.Item>
            <Form.Item name="category" label="分类">
              <Select
                showSearch
                options={categories.map((c) => ({ value: c, label: c }))}
              />
            </Form.Item>
            <Form.Item name="description" label="简介">
              <Input.TextArea rows={3} />
            </Form.Item>
            <Form.Item name="tags" label="标签">
              <Input />
            </Form.Item>
            <Form.Item name="free_episode_count" label="免费集数">
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="bundle_price" label="整剧价格">
              <InputNumber min={0} style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item name="status" label="状态">
              <Select
                options={[
                  { value: 1, label: '上架' },
                  { value: 2, label: '下架' },
                ]}
              />
            </Form.Item>
            <Button type="primary" htmlType="submit" block>
              保存
            </Button>
          </Form>
        )}
      </Modal>
    </div>
  )
}

function CategoriesPanel() {
  const [rows, setRows] = useState<CategoryStat[]>([])
  const [loading, setLoading] = useState(false)
  const [renameOpen, setRenameOpen] = useState(false)
  const [createOpen, setCreateOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [renaming, setRenaming] = useState('')
  const [deleting, setDeleting] = useState<CategoryStat | null>(null)
  const reload = async () => {
    setLoading(true)
    try {
      setRows(await listCategoryStats())
    } catch (e: any) {
      message.error(e.message)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
  }, [])
  const otherCats = rows.map((r) => r.category).filter((c) => c !== deleting?.category)
  return (
    <div className="block">
      <div className="block-hd">
        <div>
          <h2>分类管理</h2>
          <p>新增 / 编辑 / 删除 · 聚合统计</p>
        </div>
        <Space>
          <Button type="primary" onClick={() => setCreateOpen(true)}>
            新增分类
          </Button>
          <Button onClick={reload}>刷新</Button>
        </Space>
      </div>
      <div className="block-bd">
        <Table
          rowKey="category"
          loading={loading}
          dataSource={rows}
          pagination={false}
          columns={[
            { title: '分类', dataIndex: 'category' },
            { title: '剧目数', dataIndex: 'total', width: 90 },
            { title: '在线', dataIndex: 'online', width: 80 },
            {
              title: '下架',
              width: 80,
              render: (_, row) => Math.max(0, row.total - row.online),
            },
            {
              title: '播放量',
              dataIndex: 'play_sum',
              width: 100,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            {
              title: '解锁收入',
              dataIndex: 'revenue_sum',
              width: 100,
              render: (v) => Number(v || 0).toLocaleString(),
            },
            {
              title: '操作',
              width: 160,
              render: (_, row) => (
                <Space size={6}>
                  <Button
                    size="small"
                    onClick={() => {
                      setRenaming(row.category)
                      setRenameOpen(true)
                    }}
                  >
                    编辑
                  </Button>
                  <Button
                    size="small"
                    danger
                    onClick={() => {
                      setDeleting(row)
                      setDeleteOpen(true)
                    }}
                  >
                    删除
                  </Button>
                </Space>
              ),
            },
          ]}
        />
      </div>
      <Modal
        title="新增分类"
        open={createOpen}
        onCancel={() => setCreateOpen(false)}
        footer={null}
        destroyOnHidden
      >
        <Form
          layout="vertical"
          onFinish={async (v) => {
            await createCategory(String(v.name).trim())
            message.success('已创建')
            setCreateOpen(false)
            reload()
          }}
        >
          <Form.Item name="name" label="分类名" rules={[{ required: true, message: '请输入分类名' }]}>
            <Input placeholder="如：悬疑" maxLength={32} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block>
            创建
          </Button>
        </Form>
      </Modal>
      <Modal
        title={`编辑分类 · ${renaming}`}
        open={renameOpen}
        onCancel={() => setRenameOpen(false)}
        footer={null}
        destroyOnHidden
      >
        <Form
          layout="vertical"
          initialValues={{ to: renaming }}
          onFinish={async (v) => {
            const res = await renameCategory(renaming, String(v.to).trim())
            message.success(`已更新 ${res.updated} 部剧`)
            setRenameOpen(false)
            reload()
          }}
        >
          <Form.Item name="to" label="分类名" rules={[{ required: true }]}>
            <Input maxLength={32} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block>
            保存
          </Button>
        </Form>
      </Modal>
      <Modal
        title={deleting ? `删除分类 · ${deleting.category}` : '删除分类'}
        open={deleteOpen}
        onCancel={() => {
          setDeleteOpen(false)
          setDeleting(null)
        }}
        footer={null}
        destroyOnHidden
      >
        {deleting && (
          <Form
            layout="vertical"
            onFinish={async (v) => {
              const moveTo = deleting.total > 0 ? String(v.move_to || '').trim() : undefined
              if (deleting.total > 0 && !moveTo) {
                message.error('该分类下仍有剧目，请选择迁移目标')
                return
              }
              const res = await deleteCategory(deleting.category, moveTo)
              message.success(
                deleting.total > 0 ? `已删除，并迁移 ${res.moved} 部剧` : '已删除分类',
              )
              setDeleteOpen(false)
              setDeleting(null)
              reload()
            }}
          >
            {deleting.total > 0 ? (
              <>
                <p className="hint" style={{ marginBottom: 12 }}>
                  该分类下有 {deleting.total} 部剧，删除前须迁移到其他分类。
                </p>
                <Form.Item name="move_to" label="迁移到" rules={[{ required: true }]}>
                  <Select
                    options={otherCats.map((c) => ({ value: c, label: c }))}
                    placeholder="选择目标分类"
                  />
                </Form.Item>
              </>
            ) : (
              <p className="hint" style={{ marginBottom: 12 }}>
                该分类下暂无剧目，确认删除？
              </p>
            )}
            <Button type="primary" danger htmlType="submit" block>
              确认删除
            </Button>
          </Form>
        )}
      </Modal>
    </div>
  )
}

function AccountPanel() {
  const username = localStorage.getItem('admin_username') || 'admin'
  const adminId = localStorage.getItem('admin_id') || '-'
  return (
    <div className="stack" style={{ maxWidth: 560 }}>
      <div className="block">
        <div className="block-hd">
          <div>
            <h2>账号信息</h2>
            <p>当前登录的运营账号</p>
          </div>
        </div>
        <div className="block-bd">
          <div className="account-rows">
            <div>
              <span>账号</span>
              <strong>{username}</strong>
            </div>
            <div>
              <span>Admin ID</span>
              <strong>{adminId}</strong>
            </div>
            <div>
              <span>权限</span>
              <strong>内容 / 商业 / 用户运营</strong>
            </div>
          </div>
        </div>
      </div>
      <div className="block">
        <div className="block-hd">
          <div>
            <h2>修改密码</h2>
            <p>至少 6 位；修改后请重新登录</p>
          </div>
        </div>
        <div className="block-bd">
          <Form
            layout="vertical"
            onFinish={async (v) => {
              if (v.new_password !== v.confirm) {
                message.error('两次新密码不一致')
                return
              }
              await changePassword(v.old_password, v.new_password)
              message.success('密码已更新，请重新登录')
              localStorage.removeItem('admin_token')
              localStorage.removeItem('admin_username')
              localStorage.removeItem('admin_id')
              window.location.reload()
            }}
          >
            <Form.Item name="old_password" label="原密码" rules={[{ required: true }]}>
              <Input.Password />
            </Form.Item>
            <Form.Item name="new_password" label="新密码" rules={[{ required: true, min: 6 }]}>
              <Input.Password />
            </Form.Item>
            <Form.Item name="confirm" label="确认新密码" rules={[{ required: true }]}>
              <Input.Password />
            </Form.Item>
            <Button type="primary" htmlType="submit">
              保存密码
            </Button>
          </Form>
        </div>
      </div>
    </div>
  )
}

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('admin_token'))
  const [key, setKey] = useState<NavKey>('stats')

  const content = useMemo(() => {
    switch (key) {
      case 'stats':
        return <StatsPanel />
      case 'dramas':
        return <DramaPanel />
      case 'trash':
        return <DramaPanel fixedStatus="deleted" />
      case 'categories':
        return <CategoriesPanel />
      case 'top':
        return <TopDramasPanel />
      case 'unlocks':
        return <UnlocksPanel />
      case 'topups':
        return <TopupsPanel />
      case 'ledger':
        return <LedgerPanel />
      case 'wallet':
        return <WalletPanel />
      case 'users':
        return <UsersPanel />
      case 'account':
        return <AccountPanel />
      default:
        return <StatsPanel />
    }
  }, [key])

  const meta = pageMeta[key]
  const adminName = localStorage.getItem('admin_username') || 'admin'

  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: '#3d7eff',
          colorInfo: '#3d7eff',
          colorSuccess: '#1a9f6e',
          colorWarning: '#c58a00',
          colorError: '#e25555',
          colorBgBase: '#ffffff',
          colorBgContainer: '#ffffff',
          colorBorder: '#e5e6eb',
          colorText: '#1f2329',
          colorTextSecondary: '#8a8f99',
          borderRadius: 4,
          fontFamily: "'Noto Sans SC', 'PingFang SC', 'Microsoft YaHei', sans-serif",
          controlHeight: 34,
        },
      }}
    >
      {!authed ? (
        <LoginView onOk={() => setAuthed(true)} />
      ) : (
        <div className="app-shell">
          <aside className="rail">
            <div className="rail-logo">
              <strong>ZiTok</strong>
              <span>运营后台</span>
            </div>
            {navGroups.map((group) => (
              <div key={group.title} className="rail-group">
                <div className="rail-group-title">{group.title}</div>
                {group.items.map((item) => (
                  <button
                    key={item.key}
                    type="button"
                    className={key === item.key ? 'active' : undefined}
                    onClick={() => setKey(item.key)}
                  >
                    <span className="nav-label">{item.label}</span>
                    <span className="nav-desc">{item.desc}</span>
                  </button>
                ))}
              </div>
            ))}
          </aside>
          <div className="main">
            <header className="topbar">
              <div className="topbar-meta">
                <div className="crumb">
                  {meta.group}
                  <i />
                  {meta.title}
                </div>
                <h1>{meta.title}</h1>
                <span className="sub">{meta.blurb}</span>
              </div>
              <Space>
                <span className="hint" style={{ marginRight: 4 }}>
                  {adminName}
                </span>
                <Button
                  onClick={() => {
                    localStorage.removeItem('admin_token')
                    localStorage.removeItem('admin_username')
                    localStorage.removeItem('admin_id')
                    setAuthed(false)
                  }}
                >
                  退出
                </Button>
              </Space>
            </header>
            <main className="content">
              <PageFrame key={key}>{content}</PageFrame>
            </main>
          </div>
        </div>
      )}
    </ConfigProvider>
  )
}
