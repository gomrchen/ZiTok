-- ============================================================
-- 视频评论数自动统计 SQL 脚本
-- 适用于 MySQL 8.0+
-- 功能：
--   1. 初始化：统计并更新每个视频的现有评论数
--   2. 触发器：INSERT/UPDATE 时自动维护评论数
--   3. 定时事件：定期重新统计保证数据一致性
-- ============================================================

-- ============================================================
-- 第一部分：初始化 - 统计并更新现有视频的评论数
-- ============================================================

-- 一次性更新所有视频的评论数（首次运行时执行）
UPDATE video v
SET v.comment_count = (
    SELECT COUNT(*)
    FROM comments c
    WHERE c.video_id = v.id
      AND c.deleted_at IS NULL
);

-- ============================================================
-- 第二部分：触发器 - 自动维护评论数
-- ============================================================

-- 删除已存在的触发器（如果存在）
DROP TRIGGER IF EXISTS trg_comment_insert;
DROP TRIGGER IF EXISTS trg_comment_update;
DROP TRIGGER IF EXISTS trg_comment_delete;

DELIMITER //

-- 触发器1：插入评论时增加评论数
-- 只有当新评论未被软删除时才增加计数
CREATE TRIGGER trg_comment_insert
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
    IF NEW.deleted_at IS NULL THEN
        UPDATE video
        SET comment_count = comment_count + 1
        WHERE id = NEW.video_id;
    END IF;
END//

-- 触发器2：更新评论时处理软删除/恢复
-- 场景1：评论被软删除（deleted_at 从 NULL 变为非 NULL）-> 减少计数
-- 场景2：评论被恢复（deleted_at 从非 NULL 变为 NULL）-> 增加计数
CREATE TRIGGER trg_comment_update
AFTER UPDATE ON comments
FOR EACH ROW
BEGIN
    -- 软删除：之前未删除，现在删除了
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        UPDATE video
        SET comment_count = GREATEST(comment_count - 1, 0)
        WHERE id = NEW.video_id;
    -- 恢复：之前已删除，现在恢复了
    ELSEIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
        UPDATE video
        SET comment_count = comment_count + 1
        WHERE id = NEW.video_id;
    END IF;
END//

-- 触发器3：物理删除评论时减少评论数（可选，如果有物理删除场景）
CREATE TRIGGER trg_comment_delete
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
    IF OLD.deleted_at IS NULL THEN
        UPDATE video
        SET comment_count = GREATEST(comment_count - 1, 0)
        WHERE id = OLD.video_id;
    END IF;
END//

DELIMITER ;

-- ============================================================
-- 第三部分：定时事件 - 定期重新统计评论数
-- ============================================================

-- 确保事件调度器已启用
SET GLOBAL event_scheduler = ON;

-- 删除已存在的事件（如果存在）
DROP EVENT IF EXISTS evt_sync_comment_count;

DELIMITER //

-- 创建定时事件：每小时执行一次，重新统计所有视频的评论数
-- 这是一个兜底机制，确保数据一致性
CREATE EVENT evt_sync_comment_count
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
ENABLE
COMMENT '定时同步视频评论数，保证数据一致性'
DO
BEGIN
    UPDATE video v
    SET v.comment_count = (
        SELECT COUNT(*)
        FROM comments c
        WHERE c.video_id = v.id
          AND c.deleted_at IS NULL
    );
END//

DELIMITER ;

-- ============================================================
-- 第四部分：验证脚本（可选执行）
-- ============================================================

-- 查看触发器是否创建成功
-- SHOW TRIGGERS LIKE 'comments';

-- 查看事件是否创建成功
-- SHOW EVENTS;

-- 验证评论数统计是否正确
-- SELECT
--     v.id,
--     v.title,
--     v.comment_count AS current_count,
--     (SELECT COUNT(*) FROM comments c WHERE c.video_id = v.id AND c.deleted_at IS NULL) AS actual_count
-- FROM video v
-- WHERE v.deleted_at IS NULL
-- LIMIT 20;
