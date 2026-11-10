-- 商业化：钱包 / 流水 / 解锁
CREATE TABLE IF NOT EXISTS wallet (
    user_id BIGINT PRIMARY KEY,
    balance INT NOT NULL DEFAULT 0 COMMENT '金币余额',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户钱包';

CREATE TABLE IF NOT EXISTS coin_ledger (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    change_amount INT NOT NULL COMMENT '正负变动',
    balance_after INT NOT NULL,
    reason VARCHAR(64) NOT NULL COMMENT 'register_bonus/ad_reward/unlock/topup/admin',
    ref_id VARCHAR(64) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_time (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金币流水';

CREATE TABLE IF NOT EXISTS unlock_purchase (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    drama_id BIGINT NOT NULL,
    episode_id BIGINT NOT NULL DEFAULT 0 COMMENT '0表示整剧',
    unlock_type TINYINT NOT NULL COMMENT '1单集 2整剧 3广告临时',
    price INT NOT NULL DEFAULT 0,
    expire_at TIMESTAMP NULL COMMENT '临时解锁过期时间',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_ep (user_id, drama_id, episode_id, unlock_type),
    INDEX idx_user_drama (user_id, drama_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='解锁记录';

CREATE TABLE IF NOT EXISTS admin_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(64) NOT NULL UNIQUE,
    password VARCHAR(128) NOT NULL COMMENT 'md5',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='运营账号';
