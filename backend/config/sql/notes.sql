-- 使用数据库
USE videohub;

-- 创建笔记表
CREATE TABLE IF NOT EXISTS `notes` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '笔记ID',
    `user_id` bigint(20) NOT NULL COMMENT '用户ID',
    `video_id` bigint(20) NOT NULL COMMENT '视频ID（0表示用户笔记）',
    `related_user_id` bigint(20) NOT NULL COMMENT '相关用户ID（0表示视频笔记）',
    `title` varchar(255) DEFAULT NULL COMMENT '笔记标题',
    `content` text COMMENT '笔记内容',
    `seconds` int(11) DEFAULT NULL COMMENT '视频时间点（秒）',
    `status` tinyint(4) DEFAULT 0 COMMENT '状态 0:正常 1:已删除',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` timestamp NULL DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_video_id` (`video_id`),
    KEY `idx_related_user_id` (`related_user_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='笔记表';

-- 创建笔记点赞表
CREATE TABLE IF NOT EXISTS `note_likes` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '点赞ID',
    `note_id` bigint(20) NOT NULL COMMENT '笔记ID',
    `user_id` bigint(20) NOT NULL COMMENT '用户ID',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted_at` timestamp NULL DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_note_user` (`note_id`,`user_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_note_id` (`note_id`),
    KEY `idx_deleted_at` (`deleted_at`),
    CONSTRAINT `fk_note_likes_note` FOREIGN KEY (`note_id`) REFERENCES `notes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='笔记点赞表';

-- 创建笔记评论表
CREATE TABLE IF NOT EXISTS `note_comments` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '评论ID',
    `note_id` bigint(20) NOT NULL COMMENT '笔记ID',
    `user_id` bigint(20) NOT NULL COMMENT '用户ID',
    `content` text NOT NULL COMMENT '评论内容',
    `parent_id` bigint(20) DEFAULT NULL COMMENT '父评论ID（回复评论时使用）',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` timestamp NULL DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    KEY `idx_note_id` (`note_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_parent_id` (`parent_id`),
    KEY `idx_deleted_at` (`deleted_at`),
    CONSTRAINT `fk_note_comments_note` FOREIGN KEY (`note_id`) REFERENCES `notes` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_note_comments_parent` FOREIGN KEY (`parent_id`) REFERENCES `note_comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='笔记评论表';

-- 创建笔记收藏表
CREATE TABLE IF NOT EXISTS `note_favorites` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
    `note_id` bigint(20) NOT NULL COMMENT '笔记ID',
    `user_id` bigint(20) NOT NULL COMMENT '用户ID',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted_at` timestamp NULL DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_note_user` (`note_id`,`user_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_note_id` (`note_id`),
    KEY `idx_deleted_at` (`deleted_at`),
    CONSTRAINT `fk_note_favorites_note` FOREIGN KEY (`note_id`) REFERENCES `notes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='笔记收藏表';
