-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS videohub;

-- 创建用户并授权（允许从任何主机访问）
CREATE USER IF NOT EXISTS 'videohub'@'%' IDENTIFIED BY 'videohub';
GRANT ALL PRIVILEGES ON videohub.* TO 'videohub'@'%';
FLUSH PRIVILEGES;

-- 使用数据库
USE videohub;

-- 创建用户表
CREATE TABLE IF NOT EXISTS `users` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    `username` varchar(32) NOT NULL COMMENT '用户名',
    `password` varchar(128) NOT NULL COMMENT '密码',
    `email` varchar(128) NOT NULL DEFAULT '' COMMENT '邮箱',
    `avatar_url` varchar(255) NOT NULL DEFAULT '' COMMENT '头像URL',
    `background_url` varchar(255) NOT NULL DEFAULT '' COMMENT '背景图片URL',
    `signature` varchar(255) NOT NULL DEFAULT '' COMMENT '简介/个性签名',
    `gender` tinyint(1) NOT NULL DEFAULT 0 COMMENT '性别 0:未知 1:男 2:女',
    `birthday` date DEFAULT NULL COMMENT '生日',
    `status` tinyint(1) NOT NULL DEFAULT 0 COMMENT '在线状态 0:离线 1:在线',
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted_at` timestamp NULL DEFAULT NULL COMMENT '删除时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_username` (`username`),
    KEY `idx_email` (`email`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 收藏表
CREATE TABLE IF NOT EXISTS favorites (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '收藏ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    video_id BIGINT NOT NULL COMMENT '视频ID',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    deleted_at TIMESTAMP NULL DEFAULT NULL COMMENT '删除时间',
    UNIQUE KEY `idx_user_video` (`user_id`, `video_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_video_id` (`video_id`),
    KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收藏表';