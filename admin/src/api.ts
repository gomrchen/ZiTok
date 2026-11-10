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
}

export type Episode = {
  id: number
  drama_id: number
  episode_no: number
  title: string
  video_url: string
  is_free: boolean
  unlock_price: number
}

export async function login(username: string, password: string) {
  const { data } = await api.post('/login', { username, password })
  if (`${data.code}` !== '10000') throw new Error(data.message || '登录失败')
  return data.data as { token: string; admin: { id: number; username: string } }
}

export async function fetchStats() {
  const { data } = await api.get('/stats')
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as {
    drama_count: number
    episode_count: number
    unlock_count: number
    play_sum: number
  }
}

export async function listDramas(page = 1) {
  const { data } = await api.get('/dramas', { params: { page, size: 50, status: 'all' } })
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as { list: Drama[]; total: number }
}

export async function createDrama(payload: Partial<Drama>) {
  const { data } = await api.post('/dramas', payload)
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as Drama
}

export async function updateDrama(id: number, payload: Partial<Drama>) {
  const { data } = await api.put(`/dramas/${id}`, payload)
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as Drama
}

export async function offlineDrama(id: number) {
  const { data } = await api.post(`/dramas/${id}/offline`)
  if (`${data.code}` !== '10000') throw new Error(data.message)
}

export async function listEpisodes(dramaId: number) {
  const { data } = await api.get(`/dramas/${dramaId}/episodes`)
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return (data.data?.list || []) as Episode[]
}

export async function createEpisode(dramaId: number, payload: Partial<Episode>) {
  const { data } = await api.post(`/dramas/${dramaId}/episodes`, payload)
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as Episode
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
  const { data } = await api.post(`/dramas/${dramaId}/episodes/upload`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as Episode
}

export async function adjustWallet(userId: number, delta: number, reason = 'admin') {
  const { data } = await api.post('/wallet/adjust', { user_id: userId, delta, reason })
  if (`${data.code}` !== '10000') throw new Error(data.message)
  return data.data as { balance: number }
}

export default api
