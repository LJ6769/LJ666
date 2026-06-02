# Hilmi Supabase 六表

项目：`wcuvzeyusbmfwgrmugou`  
API：`https://wcuvzeyusbmfwgrmugou.supabase.co`（REST 自动加 `/rest/v1/`）

## 表结构（仅这六张）

| 表 | 说明 |
|---|---|
| `User` | 用户/主播资料 |
| `Live` | 直播间 |
| `Post` | 朋友圈 |
| `PostChat` | 帖子评论 |
| `LiveChat` | 直播间弹幕 |
| `Message` | 私信 |

## 一键部署（推荐）

1. 打开 [SQL Editor](https://supabase.com/dashboard/project/wcuvzeyusbmfwgrmugou/sql/new)
2. 粘贴并执行整个文件：`supabase/deploy_six_tables.sql`
3. 客户端 Supabase 连接见 `lib/config/supabase_config.dart`（`url`、`anonKey`）

## Sign in with Apple

iOS Bundle ID 为 **`com.live.Hilmi`**（见 `lib/config/app_config.dart` 与 Xcode `PRODUCT_BUNDLE_IDENTIFIER`）。

在 [Supabase → Authentication → Providers → Apple](https://supabase.com/dashboard/project/wcuvzeyusbmfwgrmugou/auth/providers)：

- **Client IDs** 填写：`com.live.Hilmi`（勿填旧的 `com.bedoo.doo`）
- 若仍报 `id_token` 的 `aud` 不匹配，说明 Supabase 或 Xcode 仍有一处 Bundle ID 不一致

在 [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) 确认 App ID `com.live.Hilmi` 已启用 **Sign in with Apple**，且描述文件/证书用于该 Bundle ID。

## 命令行（可选）

```bash
# 重新生成种子（素材路径：~/Downloads/Hilmi切图/Hilmi素材）
python3 supabase/scripts/generate_six_tables_seed.py
python3 supabase/scripts/build_deploy.py

# 部署 SQL 需在终端设置 SUPABASE_DB_PASSWORD 等环境变量，或见 scripts/apply_supabase_deploy.py
python3 scripts/apply_supabase_deploy.py
```

## 上传媒体

```bash
# 上传脚本需在终端设置 SUPABASE_SERVICE_ROLE_KEY
python3 scripts/upload_media.py --with-videos
python3 scripts/upload_moment_posters.py
```

素材目录默认：`/Users/mac/Downloads/Hilmi切图/Hilmi素材`

## 降低 Storage / API 出口量（客户端）

应用内重要配置见 `lib/config/config.dart`（统一导出），出口量策略见 `SupabaseEgressConfig`：

- 首页与朋友圈列表内存缓存 30 分钟（少重复 `select` 与 `createSignedUrls`）
- Signed URL 内存缓存 7 天，过期前 48 小时不重新签名
- 图片按 Storage 路径磁盘缓存（`CachedMediaImage` 的 `cacheKey`），换 token 不重复下载
- 拉黑后本地过滤列表，不整页重拉
- 仅在用户下拉刷新、发帖成功等场景 `forceRefresh`

设置里「清除缓存」会清空上述内存与图片磁盘缓存。

## 内购商品 ID

App Store Connect 真实商品 ID 与金币映射见 `lib/config/iap_config.dart`。  
部署或更新数据库时请执行 `supabase/migrations/20260629160000_iap_aimoss_products.sql`（更新 `iap_coins_for_product`），否则购买会报 `unknown product`。
