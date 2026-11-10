-- 评论/点赞目标语义切换说明：
-- interaction 表字段仍为 video_id，短剧场景写入 episode.id。
-- 新增 Gateway 路由：
--   GET  /api/v1/episode/:episode_id/comments
--   POST /api/v1/episode/:episode_id/comment
--   POST /api/v1/episode/:episode_id/like
-- 无需改表；旧 video 评论与新 episode 评论按 id 空间区分。
SELECT 1;
