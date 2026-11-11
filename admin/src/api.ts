import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1/admin',
})

api.interceptors.request.use((cfg) => {
  const token = localStorage.getItem('admin_token')
  if (token) cfg.headers.Authorization = `Bearer ${token}`
  return cfg
})

export type Drama = {
  id: number
  title: string
  cover_url: string
  description: string
  category: string
  tags: string
  total_episodes: number
  free_episode_count: number
  bundle_price: number
  status: number
  play_count: number
  unlock_revenue?: number
}

export type Episode = {
  id: number
  drama_id: number
  episode_no: number
  title: string
  video_url: string
  is_free: boolean
  unlock_price: number
  visit_count?: number
  duration?: number
}

export type EpisodeOpsStat = {
  id: number
  drama_id: number
  episode_no: number
  title: string
  is_free: boolean
  unlock_price: number
  visit_count: number
  duration: number
  unlock_count: number
  unlock_revenue: number
}

export type LedgerItem = {
  id: number
  user_id: number
  change_amount: number
  balance_after: number
  reason: string
  ref_id: string
  created_at: string
}

export type UnlockItem = {
  id: number
  user_id: number
  username?: string
  drama_id: number
  drama_title?: string
  episode_id?: number
  unlock_type: number
  price: number
  expire_at?: string
  expired?: boolean
  created_at?: string
}

export type UserBrief = {
  id: number
  username: string
  avatar_url: string
  balance: number
}

export type UnlockTypeStat = {
  unlock_type: number
  count: number
  revenue: number
}

export type DailyRevenuePoint = {
  date: string
  revenue: number
  count: number
}

export type CategoryStat = {
  category: string
  total: number
  online: number
  play_sum: number
  revenue_sum?: number
}

export type UserCommerceSummary = {
  username?: string
  avatar_url?: string
  created_at?: string
  topup_sum?: number
  spend_sum?: number
  unlock_count?: number
  last_watch_at?: string
}

export type AdminStats = {
  drama_count: number
  online_count: number
  episode_count: number
  unlock_count: number
  play_sum: number
  user_count: number
  coin_sum: number
  top_dramas?: Drama[]
  unlock_revenue?: number
  today_unlocks?: number
  today_revenue?: number
  today_topup_amt?: number
  today_topup_cnt?: number
  ad_unlock_count?: number
  unlock_types?: UnlockTypeStat[]
  daily_revenue?: DailyRevenuePoint[]
  daily_signups?: DailyRevenuePoint[]
  daily_topups?: DailyRevenuePoint[]
  recent_unlocks?: UnlockItem[]
  recent_topups?: LedgerItem[]
}

export type DramaOpsStat = {
  drama_id: number
  title: string
  status: number
  play_count: number
  episode_count: number
  unlock_count: number
  unlock_revenue: number
  watching_count: number
  fav_count: number
}

export type WatchProgress = {
  id: number
  user_id: number
  drama_id: number
  episode_id: number
  episode_no: number
  position_sec: number
  updated_at?: string
}

export type UserDetail = {
  user_id: number
  balance: number
  ledger: LedgerItem[]
  unlocks: UnlockItem[]
  watching: WatchProgress[]
  favorites: Drama[]
  fav_count: number
  watch_count: number
  summary?: UserCommerceSummary
}

async function unwrap<T>(p: Promise<{ data: any }>): Promise<T> {
  const { data } = await p
  if (`${data.code}` !== '10000') throw new Error(data.message || '请求失败')
  return data.data as T
}

export async function login(username: string, password: string) {
  return unwrap<{ token: string; admin: { id: number; username: string } }>(
    api.post('/login', { username, password }),
  )
}

export async function fetchStats() {
  return unwrap<AdminStats>(api.get('/stats'))
}

export async function listDramas(opts?: {
  page?: number
  size?: number
  q?: string
  status?: string
  category?: string
  sort?: string
}) {
  return unwrap<{ list: Drama[]; total: number }>(
    api.get('/dramas', {
      params: {
        page: opts?.page ?? 1,
        size: opts?.size ?? 20,
        status: opts?.status ?? 'all',
        q: opts?.q || undefined,
        category: opts?.category || undefined,
        sort: opts?.sort || undefined,
      },
    }),
  )
}

export async function createDrama(payload: Partial<Drama>) {
  return unwrap<Drama>(api.post('/dramas', payload))
}

export async function updateDrama(id: number, payload: Partial<Drama>) {
  return unwrap<Drama>(api.put(`/dramas/${id}`, payload))
}

export async function offlineDrama(id: number) {
  await unwrap<unknown>(api.post(`/dramas/${id}/offline`))
}

export async function onlineDrama(id: number) {
  await unwrap<unknown>(api.post(`/dramas/${id}/online`))
}

export async function listEpisodes(dramaId: number) {
  const data = await unwrap<{ list: Episode[] }>(api.get(`/dramas/${dramaId}/episodes`))
  return data.list || []
}

export async function createEpisode(dramaId: number, payload: Partial<Episode>) {
  return unwrap<Episode>(api.post(`/dramas/${dramaId}/episodes`, payload))
}

export async function updateEpisode(episodeId: number, payload: Partial<Episode>) {
  return unwrap<Episode>(api.put(`/episodes/${episodeId}`, payload))
}

export async function deleteEpisode(episodeId: number) {
  await unwrap<unknown>(api.delete(`/episodes/${episodeId}`))
}

export async function uploadEpisode(
  dramaId: number,
  file: File,
  opts: { episode_no?: number; title?: string; is_free?: boolean; unlock_price?: number },
) {
  const fd = new FormData()
  fd.append('video', file)
  if (opts.episode_no) fd.append('episode_no', String(opts.episode_no))
  if (opts.title) fd.append('title', opts.title)
  fd.append('is_free', opts.is_free ? 'true' : 'false')
  fd.append('unlock_price', String(opts.unlock_price ?? 10))
  return unwrap<Episode>(
    api.post(`/dramas/${dramaId}/episodes/upload`, fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  )
}

export async function adjustWallet(userId: number, delta: number, reason = 'admin') {
  return unwrap<{ balance: number }>(api.post('/wallet/adjust', { user_id: userId, delta, reason }))
}

export async function getWallet(userId: number) {
  return unwrap<{ user_id: number; balance: number; ledger: LedgerItem[] }>(api.get(`/wallet/${userId}`))
}

export async function listLedger(opts?: { user_id?: number; reason?: string; limit?: number }) {
  const data = await unwrap<{ list: LedgerItem[] }>(
    api.get('/ledger', {
      params: {
        user_id: opts?.user_id || undefined,
        reason: opts?.reason || undefined,
        limit: opts?.limit ?? 50,
      },
    }),
  )
  return data.list || []
}

export async function listUnlocks(opts?: {
  limit?: number
  user_id?: number
  drama_id?: number
  unlock_type?: number
  expired_only?: boolean
}) {
  const data = await unwrap<{ list: UnlockItem[] }>(
    api.get('/unlocks', {
      params: {
        limit: opts?.limit ?? 50,
        user_id: opts?.user_id || undefined,
        drama_id: opts?.drama_id || undefined,
        unlock_type: opts?.unlock_type || undefined,
        expired_only: opts?.expired_only ? '1' : undefined,
      },
    }),
  )
  return data.list || []
}

export async function searchUsers(q: string) {
  const data = await unwrap<{ list: UserBrief[] }>(api.get('/users/search', { params: { q } }))
  return data.list || []
}

export async function listUsers(opts?: { q?: string; page?: number; size?: number; sort?: string }) {
  return unwrap<{ list: UserBrief[]; total: number }>(
    api.get('/users', {
      params: {
        q: opts?.q || undefined,
        page: opts?.page ?? 1,
        size: opts?.size ?? 20,
        sort: opts?.sort || undefined,
      },
    }),
  )
}

export async function getUserDetail(userId: number) {
  return unwrap<UserDetail>(api.get(`/users/${userId}`))
}

export async function adminTopup(userId: number, amount: number) {
  return unwrap<{ balance: number }>(api.post('/wallet/topup', { user_id: userId, amount }))
}

export async function listTopups(opts?: { limit?: number; user_id?: number }) {
  const data = await unwrap<{ list: LedgerItem[] }>(
    api.get('/topups', {
      params: { limit: opts?.limit ?? 30, user_id: opts?.user_id || undefined },
    }),
  )
  return data.list || []
}

export async function listTopDramas(limit = 10, sort: 'play' | 'revenue' = 'play') {
  const data = await unwrap<{ list: Drama[] }>(
    api.get('/dramas/top', { params: { limit, sort } }),
  )
  return data.list || []
}

export async function batchEpisodePricing(dramaId: number, freeCount: number, unlockPrice: number) {
  return unwrap<{ updated: number }>(
    api.post(`/dramas/${dramaId}/pricing`, { free_count: freeCount, unlock_price: unlockPrice }),
  )
}

export async function uploadCover(file: File, dramaId?: number) {
  const fd = new FormData()
  fd.append('cover', file)
  if (dramaId) fd.append('drama_id', String(dramaId))
  return unwrap<{ cover_url: string }>(
    api.post('/covers/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } }),
  )
}

export async function deleteDrama(id: number) {
  await unwrap<unknown>(api.delete(`/dramas/${id}`))
}

export async function restoreDrama(id: number) {
  await unwrap<unknown>(api.post(`/dramas/${id}/restore`))
}

export async function batchDramaStatus(ids: number[], status: 1 | 2) {
  return unwrap<{ updated: number }>(api.post('/dramas/batch-status', { ids, status }))
}

export async function listCategories() {
  const data = await unwrap<{ list: string[]; stats?: CategoryStat[] }>(api.get('/categories'))
  return data.list || []
}

export async function listCategoryStats() {
  const data = await unwrap<{ list: string[]; stats?: CategoryStat[] }>(api.get('/categories'))
  return data.stats || []
}

export async function createCategory(name: string, sortOrder = 0) {
  return unwrap<{ name: string }>(api.post('/categories', { name, sort_order: sortOrder }))
}

export async function renameCategory(from: string, to: string) {
  return unwrap<{ updated: number }>(api.post('/categories/rename', { from, to }))
}

export async function deleteCategory(name: string, moveTo?: string) {
  return unwrap<{ moved: number }>(
    api.post('/categories/delete', { name, move_to: moveTo || undefined }),
  )
}

export async function batchRestoreDramas(ids: number[]) {
  return unwrap<{ updated: number }>(api.post('/dramas/batch-restore', { ids }))
}

export async function purgeDrama(id: number) {
  await unwrap<unknown>(api.delete(`/dramas/${id}/purge`))
}

export async function batchPurgeDramas(ids: number[]) {
  return unwrap<{ deleted: number }>(api.post('/dramas/batch-purge', { ids }))
}

export async function changePassword(oldPassword: string, newPassword: string) {
  await unwrap<unknown>(api.post('/account/password', { old_password: oldPassword, new_password: newPassword }))
}

export async function getDramaDetail(id: number) {
  return unwrap<{ drama: Drama; episodes: Episode[]; stats: DramaOpsStat; episode_stats?: EpisodeOpsStat[] }>(
    api.get(`/dramas/${id}`),
  )
}

export async function getDramaStats(id: number) {
  return unwrap<DramaOpsStat>(api.get(`/dramas/${id}/stats`))
}

export async function reorderEpisode(episodeId: number, episodeNo: number) {
  await unwrap<unknown>(api.post(`/episodes/${episodeId}/reorder`, { episode_no: episodeNo }))
}

export async function grantUnlock(payload: {
  user_id: number
  drama_id: number
  episode_id?: number
  unlock_type: number
}) {
  await unwrap<unknown>(api.post('/unlocks/grant', payload))
}

export async function revokeUnlock(id: number, refund = false) {
  await unwrap<unknown>(api.delete(`/unlocks/${id}`, { params: { refund: refund ? '1' : '0' } }))
}

export default api
