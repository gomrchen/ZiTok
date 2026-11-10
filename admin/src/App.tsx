import { useEffect, useMemo, useState } from 'react'
import {
  Layout,
  Menu,
  Form,
  Input,
  Button,
  Table,
  Card,
  Space,
  Modal,
  InputNumber,
  Select,
  message,
  Typography,
  Statistic,
  Row,
  Col,
  Tag,
  Upload,
  Divider,
} from 'antd'
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
  updateDrama,
  adjustWallet,
  type Drama,
  type Episode,
} from './api'
import './App.css'

const { Header, Sider, Content } = Layout

function LoginView({ onOk }: { onOk: () => void }) {
  const [loading, setLoading] = useState(false)
  return (
    <div className="login-wrap">
      <Card title="ZiTok 短剧运营后台" style={{ width: 380 }}>
        <Form
          layout="vertical"
          initialValues={{ username: 'admin', password: 'admin123' }}
          onFinish={async (v) => {
            setLoading(true)
            try {
              const data = await login(v.username, v.password)
              localStorage.setItem('admin_token', data.token)
              message.success('登录成功')
              onOk()
            } catch (e: any) {
              message.error(e.message || '登录失败')
            } finally {
              setLoading(false)
            }
          }}
        >
          <Form.Item name="username" label="账号" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="password" label="密码" rules={[{ required: true }]}>
            <Input.Password />
          </Form.Item>
          <Button type="primary" htmlType="submit" block loading={loading}>
            登录
          </Button>
        </Form>
      </Card>
    </div>
  )
}

function StatsPanel() {
  const [stats, setStats] = useState({ drama_count: 0, episode_count: 0, unlock_count: 0, play_sum: 0 })
  useEffect(() => {
    fetchStats().then(setStats).catch(() => {})
  }, [])
  return (
    <Row gutter={16}>
      <Col span={6}><Card><Statistic title="在线剧" value={stats.drama_count} /></Card></Col>
      <Col span={6}><Card><Statistic title="集数" value={stats.episode_count} /></Card></Col>
      <Col span={6}><Card><Statistic title="解锁次数" value={stats.unlock_count} /></Card></Col>
      <Col span={6}><Card><Statistic title="播放量" value={stats.play_sum} /></Card></Col>
    </Row>
  )
}

function DramaPanel() {
  const [list, setList] = useState<Drama[]>([])
  const [loading, setLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [epOpen, setEpOpen] = useState(false)
  const [current, setCurrent] = useState<Drama | null>(null)
  const [episodes, setEpisodes] = useState<Episode[]>([])

  const reload = async () => {
    setLoading(true)
    try {
      const data = await listDramas()
      setList(data.list || [])
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
    <Card
      title="剧目管理"
      extra={
        <Button type="primary" onClick={() => setOpen(true)}>
          新建剧
        </Button>
      }
    >
      <Table
        rowKey="id"
        loading={loading}
        dataSource={list}
        columns={[
          { title: 'ID', dataIndex: 'id', width: 70 },
          { title: '剧名', dataIndex: 'title' },
          { title: '分类', dataIndex: 'category', width: 90 },
          { title: '集数', dataIndex: 'total_episodes', width: 80 },
          {
            title: '状态',
            dataIndex: 'status',
            width: 90,
            render: (v) => (v === 1 ? <Tag color="green">上架</Tag> : <Tag>下架/草稿</Tag>),
          },
          {
            title: '操作',
            width: 260,
            render: (_, row) => (
              <Space>
                <Button
                  size="small"
                  onClick={async () => {
                    setCurrent(row)
                    setEpisodes(await listEpisodes(row.id))
                    setEpOpen(true)
                  }}
                >
                  分集
                </Button>
                <Button
                  size="small"
                  onClick={async () => {
                    await updateDrama(row.id, { ...row, status: 1 })
                    message.success('已上架')
                    reload()
                  }}
                >
                  上架
                </Button>
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
              </Space>
            ),
          },
        ]}
      />

      <Modal
        title="新建剧"
        open={open}
        onCancel={() => setOpen(false)}
        footer={null}
        destroyOnClose
      >
        <Form
          layout="vertical"
          initialValues={{ category: '甜宠', free_episode_count: 3, bundle_price: 80, status: 1 }}
          onFinish={async (v) => {
            await createDrama(v)
            message.success('创建成功')
            setOpen(false)
            reload()
          }}
        >
          <Form.Item name="title" label="剧名" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="cover_url" label="封面 URL">
            <Input placeholder="https://..." />
          </Form.Item>
          <Form.Item name="description" label="简介">
            <Input.TextArea rows={3} />
          </Form.Item>
          <Form.Item name="category" label="分类">
            <Select
              options={[
                { value: '甜宠', label: '甜宠' },
                { value: '古装', label: '古装' },
                { value: '青春', label: '青春' },
              ]}
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
        title={current ? `分集 · ${current.title}` : '分集'}
        open={epOpen}
        onCancel={() => setEpOpen(false)}
        width={720}
        footer={null}
      >
        <Table
          size="small"
          rowKey="id"
          dataSource={episodes}
          pagination={false}
          columns={[
            { title: '集', dataIndex: 'episode_no', width: 60 },
            { title: '标题', dataIndex: 'title' },
            { title: '免费', dataIndex: 'is_free', width: 70, render: (v) => (v ? '是' : '否') },
            { title: '价格', dataIndex: 'unlock_price', width: 70 },
            {
              title: '视频',
              dataIndex: 'video_url',
              ellipsis: true,
            },
          ]}
        />
        <Divider>URL 添加</Divider>
        <Form
          style={{ marginTop: 8 }}
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
            <Input placeholder="视频 URL" style={{ width: 260 }} />
          </Form.Item>
          <Form.Item name="unlock_price" initialValue={10}>
            <InputNumber placeholder="价格" min={0} />
          </Form.Item>
          <Form.Item name="is_free">
            <Select
              allowClear
              placeholder="免费?"
              style={{ width: 90 }}
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

        <Divider>本地上传</Divider>
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
              style={{ width: 90 }}
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
              <Button>选择视频</Button>
            </Upload>
          </Form.Item>
          <Button type="primary" htmlType="submit">
            上传
          </Button>
        </Form>
      </Modal>
    </Card>
  )
}

function WalletPanel() {
  return (
    <Card title="用户调账">
      <Form
        layout="inline"
        onFinish={async (v) => {
          const res = await adjustWallet(v.user_id, v.delta, v.reason || 'admin')
          message.success(`调账成功，余额 ${res.balance}`)
        }}
      >
        <Form.Item name="user_id" rules={[{ required: true }]}>
          <InputNumber placeholder="用户ID" style={{ width: 140 }} />
        </Form.Item>
        <Form.Item name="delta" rules={[{ required: true }]}>
          <InputNumber placeholder="变动(+/-)" style={{ width: 140 }} />
        </Form.Item>
        <Form.Item name="reason">
          <Input placeholder="原因" />
        </Form.Item>
        <Button type="primary" htmlType="submit">
          提交
        </Button>
      </Form>
    </Card>
  )
}

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('admin_token'))
  const [key, setKey] = useState('dramas')

  const content = useMemo(() => {
    if (key === 'stats') return <StatsPanel />
    if (key === 'wallet') return <WalletPanel />
    return <DramaPanel />
  }, [key])

  if (!authed) return <LoginView onOk={() => setAuthed(true)} />

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider theme="light" width={200}>
        <div className="brand">ZiTok Admin</div>
        <Menu
          selectedKeys={[key]}
          onClick={(e) => setKey(e.key)}
          items={[
            { key: 'dramas', label: '剧目 CMS' },
            { key: 'stats', label: '数据概览' },
            { key: 'wallet', label: '用户调账' },
          ]}
        />
      </Sider>
      <Layout>
        <Header style={{ background: '#fff', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography.Text strong>运营后台</Typography.Text>
          <Button
            onClick={() => {
              localStorage.removeItem('admin_token')
              setAuthed(false)
            }}
          >
            退出
          </Button>
        </Header>
        <Content style={{ padding: 24 }}>{content}</Content>
      </Layout>
    </Layout>
  )
}
