-- 短剧：剧 / 集 / 追剧 / 进度
CREATE TABLE IF NOT EXISTS drama (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '剧ID',
    title VARCHAR(128) NOT NULL COMMENT '剧名',
    cover_url VARCHAR(512) NOT NULL DEFAULT '' COMMENT '封面',
    description VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '简介',
    category VARCHAR(32) NOT NULL DEFAULT '甜宠' COMMENT '分类',
    tags VARCHAR(255) NOT NULL DEFAULT '' COMMENT '标签逗号分隔',
    total_episodes INT NOT NULL DEFAULT 0 COMMENT '总集数',
    free_episode_count INT NOT NULL DEFAULT 3 COMMENT '免费集数',
    bundle_price INT NOT NULL DEFAULT 0 COMMENT '整剧金币价，0表示不支持整购',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '0草稿 1上架 2下架',
    play_count BIGINT NOT NULL DEFAULT 0 COMMENT '播放量',
    like_count BIGINT NOT NULL DEFAULT 0 COMMENT '点赞数',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    INDEX idx_status_category (status, category),
    INDEX idx_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短剧';

CREATE TABLE IF NOT EXISTS episode (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '集ID',
    drama_id BIGINT NOT NULL COMMENT '所属剧',
    episode_no INT NOT NULL COMMENT '第几集从1开始',
    title VARCHAR(128) NOT NULL DEFAULT '' COMMENT '集标题',
    video_url VARCHAR(512) NOT NULL COMMENT '播放地址',
    cover_url VARCHAR(512) NOT NULL DEFAULT '' COMMENT '封面',
    duration BIGINT NOT NULL DEFAULT 0 COMMENT '秒',
    is_free BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否免费',
    unlock_price INT NOT NULL DEFAULT 10 COMMENT '解锁金币',
    visit_count BIGINT NOT NULL DEFAULT 0,
    like_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    UNIQUE KEY uk_drama_ep (drama_id, episode_no),
    INDEX idx_drama (drama_id),
    INDEX idx_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='剧集';

CREATE TABLE IF NOT EXISTS user_watch_progress (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    drama_id BIGINT NOT NULL,
    episode_id BIGINT NOT NULL,
    episode_no INT NOT NULL DEFAULT 1,
    position_sec INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_drama (user_id, drama_id),
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='观看进度';

CREATE TABLE IF NOT EXISTS user_drama_favorite (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    drama_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_drama (user_id, drama_id),
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='追剧';
