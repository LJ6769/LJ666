-- =============================================================================
-- 希尔米 Hilmi 项目 · MySQL 8.0 建表脚本（中文注释）
-- 使用方法：Navicat → 文件 → 运行 SQL 文件 → 选择本文件
-- 数据库名：hilmi  字符集：utf8mb4（支持中文）
-- 说明：14 张表，字段 COMMENT 均为中文，详见「Hilmi_MySQL8数据库字段说明.txt」
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 若需重建，取消下面两行注释（会删除整个库）
-- DROP DATABASE IF EXISTS hilmi;
-- CREATE DATABASE hilmi DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS hilmi
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE hilmi;

-- -----------------------------------------------------------------------------
-- 1. users 用户 / 主播（合并原 User + auth.users）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户主键',
  email             VARCHAR(255)    NULL COMMENT '登录邮箱',
  password_hash     VARCHAR(255)    NULL COMMENT '密码哈希，Apple 登录可空',
  apple_user_id     VARCHAR(128)    NULL COMMENT 'Apple 登录唯一 ID',
  display_name      VARCHAR(100)    NOT NULL COMMENT '显示昵称',
  gender            ENUM('male','female','other') NULL COMMENT '性别',
  bio               TEXT            NULL COMMENT '个人简介',
  avatar_url        VARCHAR(512)    NULL COMMENT '头像 URL 或存储路径',
  coins             INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '金币余额',
  avatar_frame_index INT UNSIGNED   NOT NULL DEFAULT 0 COMMENT '头像框索引',
  is_popular_star   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否明星主播 1是0否',
  popular_star_sort INT UNSIGNED    NULL COMMENT '明星展示排序，越小越靠前',
  eula_accepted_at      DATETIME(3) NULL COMMENT '注册同意 EULA 时间',
  eula_login_accepted_at DATETIME(3) NULL COMMENT '登录同意 EULA 时间',
  status            TINYINT         NOT NULL DEFAULT 1 COMMENT '1正常 0禁用',
  created_at        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  updated_at        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  UNIQUE KEY uk_users_apple (apple_user_id),
  KEY idx_users_popular_star (is_popular_star, popular_star_sort)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户与主播资料';

-- -----------------------------------------------------------------------------
-- 2. user_follows 关注关系（替代 following_ids / follower_ids 数组）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS user_follows;
CREATE TABLE user_follows (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  follower_id   BIGINT UNSIGNED NOT NULL COMMENT '关注者用户 ID',
  following_id  BIGINT UNSIGNED NOT NULL COMMENT '被关注者用户 ID',
  created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '关注时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_follow_pair (follower_id, following_id),
  KEY idx_follower (follower_id),
  KEY idx_following (following_id),
  CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_follows_following FOREIGN KEY (following_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户关注关系';

-- -----------------------------------------------------------------------------
-- 3. user_blocks 拉黑（替代 blocked_ids 数组）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS user_blocks;
CREATE TABLE user_blocks (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  user_id         BIGINT UNSIGNED NOT NULL COMMENT '操作者用户 ID',
  blocked_user_id BIGINT UNSIGNED NOT NULL COMMENT '被拉黑用户 ID',
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '拉黑时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_block_pair (user_id, blocked_user_id),
  KEY idx_blocks_user (user_id),
  CONSTRAINT fk_blocks_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户拉黑';

-- -----------------------------------------------------------------------------
-- 4. iap_transactions 内购交易幂等（替代 iap_processed_tx_ids 数组）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS iap_transactions;
CREATE TABLE iap_transactions (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  user_id         BIGINT UNSIGNED NOT NULL COMMENT '用户 ID',
  product_id      VARCHAR(64)     NOT NULL COMMENT '商店商品 ID',
  transaction_id  VARCHAR(128)    NOT NULL COMMENT '交易号，全局唯一',
  coins_granted   INT UNSIGNED    NOT NULL COMMENT '本次发放金币',
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '处理时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_iap_transaction (transaction_id),
  KEY idx_iap_user (user_id),
  CONSTRAINT fk_iap_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='内购发货记录';

-- -----------------------------------------------------------------------------
-- 5. live_rooms 直播间（原 Live）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS live_rooms;
CREATE TABLE live_rooms (
  id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '直播间主键',
  category_slug       VARCHAR(64)     NOT NULL COMMENT '分类标识 popular/tutorials 等',
  category_name       VARCHAR(100)    NOT NULL COMMENT '分类显示名',
  category_sort_order INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '分类排序',
  show_on_home        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否首页展示',
  streamer_id         BIGINT UNSIGNED NOT NULL COMMENT '主播用户 ID',
  room_index          INT UNSIGNED    NOT NULL COMMENT '分类内房间序号',
  description         TEXT            NOT NULL COMMENT '房间描述',
  tags                JSON            NULL COMMENT '标签 JSON 数组',
  cover_url           VARCHAR(512)    NULL COMMENT '封面地址',
  video_url           VARCHAR(512)    NULL COMMENT '视频地址',
  viewer_count        INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '当前观众数',
  is_live             TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否直播中',
  sort_order          INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '列表排序',
  created_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  updated_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_live_category_room (category_slug, room_index),
  KEY idx_live_home (show_on_home, category_sort_order),
  KEY idx_live_streamer (streamer_id),
  CONSTRAINT fk_live_streamer FOREIGN KEY (streamer_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='调酒直播间';

-- -----------------------------------------------------------------------------
-- 6. live_chats 直播弹幕（原 LiveChat）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS live_chats;
CREATE TABLE live_chats (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '弹幕主键',
  live_room_id  BIGINT UNSIGNED NOT NULL COMMENT '直播间 ID',
  sender_id     BIGINT UNSIGNED NULL COMMENT '发送者，游客可为 NULL',
  content       VARCHAR(500)    NOT NULL COMMENT '弹幕内容',
  created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  PRIMARY KEY (id),
  KEY idx_live_chats_room_time (live_room_id, created_at),
  KEY idx_live_chats_sender (sender_id),
  CONSTRAINT fk_live_chats_room FOREIGN KEY (live_room_id) REFERENCES live_rooms (id) ON DELETE CASCADE,
  CONSTRAINT fk_live_chats_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='直播弹幕';

-- -----------------------------------------------------------------------------
-- 7. posts 朋友圈帖子（原 Post）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS posts;
CREATE TABLE posts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '帖子主键',
  post_index     INT UNSIGNED    NOT NULL COMMENT '全局帖子序号',
  author_id      BIGINT UNSIGNED NOT NULL COMMENT '作者用户 ID',
  content        TEXT            NOT NULL COMMENT '文字内容',
  like_count     INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '点赞数',
  comment_count  INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '评论数',
  media          JSON            NOT NULL COMMENT '媒体JSON数组：图片含type/storage_path/sort_order；视频另含poster_path',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发布时间',
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_posts_post_index (post_index),
  KEY idx_posts_author (author_id),
  KEY idx_posts_created (created_at),
  CONSTRAINT fk_posts_author FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='朋友圈帖子';

-- -----------------------------------------------------------------------------
-- 8. post_comments 帖子评论（原 PostChat）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS post_comments;
CREATE TABLE post_comments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '评论主键',
  post_id     BIGINT UNSIGNED NOT NULL COMMENT '帖子 ID',
  author_id   BIGINT UNSIGNED NOT NULL COMMENT '评论者 ID',
  content     TEXT            NOT NULL COMMENT '评论内容',
  created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '评论时间',
  PRIMARY KEY (id),
  KEY idx_post_comments_post (post_id, created_at),
  KEY idx_post_comments_author (author_id),
  CONSTRAINT fk_post_comments_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
  CONSTRAINT fk_post_comments_author FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帖子评论';

-- -----------------------------------------------------------------------------
-- 9. post_likes 帖子点赞（替代 liked_post_ids 数组）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS post_likes;
CREATE TABLE post_likes (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  user_id     BIGINT UNSIGNED NOT NULL COMMENT '点赞用户 ID',
  post_id     BIGINT UNSIGNED NOT NULL COMMENT '帖子 ID',
  created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '点赞时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_post_like (user_id, post_id),
  KEY idx_post_likes_post (post_id),
  CONSTRAINT fk_post_likes_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_post_likes_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帖子点赞';

-- -----------------------------------------------------------------------------
-- 10. conversations 私信会话（原 Message header）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS conversations;
CREATE TABLE conversations (
  id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '会话主键',
  user_low_id           BIGINT UNSIGNED NOT NULL COMMENT '双方较小用户 ID',
  user_high_id          BIGINT UNSIGNED NOT NULL COMMENT '双方较大用户 ID',
  last_message_at       DATETIME(3)     NULL COMMENT '最后消息时间',
  last_message_preview  VARCHAR(200)    NULL COMMENT '会话列表预览',
  last_sender_id        BIGINT UNSIGNED NULL COMMENT '最后发送者 ID',
  created_at            DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  updated_at            DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_conversation_users (user_low_id, user_high_id),
  KEY idx_conversations_last (last_message_at),
  CONSTRAINT chk_conversation_order CHECK (user_low_id < user_high_id),
  CONSTRAINT fk_conv_low FOREIGN KEY (user_low_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_conv_high FOREIGN KEY (user_high_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_conv_last_sender FOREIGN KEY (last_sender_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='私信会话摘要';

-- -----------------------------------------------------------------------------
-- 11. direct_messages 私信消息（原 Message chat）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS direct_messages;
CREATE TABLE direct_messages (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '消息主键',
  conversation_id  BIGINT UNSIGNED NOT NULL COMMENT '会话 ID',
  sender_id        BIGINT UNSIGNED NOT NULL COMMENT '发送者 ID',
  body             TEXT            NOT NULL COMMENT '消息正文',
  created_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  PRIMARY KEY (id),
  KEY idx_dm_conversation (conversation_id, created_at),
  KEY idx_dm_sender (sender_id),
  CONSTRAINT fk_dm_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_dm_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='私信消息';

-- -----------------------------------------------------------------------------
-- 12. chat_rooms Tipsy Bar 聊天室（原 ChatRoom）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS chat_rooms;
CREATE TABLE chat_rooms (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '聊天室主键',
  room_index      INT UNSIGNED    NOT NULL COMMENT '房间全局序号',
  title           VARCHAR(200)    NOT NULL COMMENT '标题',
  description     TEXT            NOT NULL COMMENT '描述',
  cover_url       VARCHAR(512)    NOT NULL COMMENT '封面地址',
  image_on_right  TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '首页卡片图靠右',
  show_on_home    TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否首页展示',
  sort_order      INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '列表排序',
  host_audio_url  VARCHAR(512)    NULL COMMENT '房主语音地址',
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_chat_rooms_index (room_index),
  KEY idx_chat_rooms_home (show_on_home, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tipsy Bar 聊天室';

-- -----------------------------------------------------------------------------
-- 13. chat_room_members 聊天室成员（原 ChatRoomMember）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS chat_room_members;
CREATE TABLE chat_room_members (
  chat_room_id  BIGINT UNSIGNED NOT NULL COMMENT '聊天室 ID',
  user_id       BIGINT UNSIGNED NOT NULL COMMENT '成员用户 ID',
  sort_order    INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '0=房主 其余=嘉宾',
  PRIMARY KEY (chat_room_id, user_id),
  KEY idx_members_user (user_id),
  CONSTRAINT fk_members_room FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id) ON DELETE CASCADE,
  CONSTRAINT fk_members_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='聊天室成员';

-- -----------------------------------------------------------------------------
-- 14. chat_room_messages 聊天室公屏（原 ChatRoomChat）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS chat_room_messages;
CREATE TABLE chat_room_messages (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '消息主键',
  chat_room_id  BIGINT UNSIGNED NOT NULL COMMENT '聊天室 ID',
  sender_id     BIGINT UNSIGNED NULL COMMENT '发送者 ID',
  content       VARCHAR(500)    NOT NULL COMMENT '公屏内容',
  created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  PRIMARY KEY (id),
  KEY idx_crm_room_time (chat_room_id, created_at),
  KEY idx_crm_sender (sender_id),
  CONSTRAINT fk_crm_room FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='聊天室公屏消息';

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 可选：评论数触发器（插入评论后 posts.comment_count +1）
-- =============================================================================
DROP TRIGGER IF EXISTS trg_post_comment_insert;
DELIMITER $$
CREATE TRIGGER trg_post_comment_insert
AFTER INSERT ON post_comments
FOR EACH ROW
BEGIN
  UPDATE posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
END$$
DELIMITER ;

-- =============================================================================
-- 可选：私信发送后更新会话摘要（应用层也可实现）
-- =============================================================================
DROP TRIGGER IF EXISTS trg_direct_message_after_insert;
DELIMITER $$
CREATE TRIGGER trg_direct_message_after_insert
AFTER INSERT ON direct_messages
FOR EACH ROW
BEGIN
  UPDATE conversations
  SET
    last_message_at = NEW.created_at,
    last_message_preview = LEFT(TRIM(NEW.body), 200),
    last_sender_id = NEW.sender_id,
    updated_at = NEW.created_at
  WHERE id = NEW.conversation_id;
END$$
DELIMITER ;

-- =============================================================================
-- IAP 商品金币映射（原 iap_coins_for_product，供后端参考）
-- product_id -> coins: mgwtghzkyzayvhbw=400, ijwhpdnfcbtmhcsm=800,
-- rsdzurddehlcrqzu=2450, unyqcpbgddjxgwwu=5150, sikxnzlzflsjwubp=10800,
-- dncewabylvgxxify=29400, szhwifwbucazxgkf=63700
-- =============================================================================

SELECT '希尔米 Hilmi 数据库创建完成' AS 执行结果;
