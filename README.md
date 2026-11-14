# 文明重启（Lumen）

**主题：教人（Enlighten Ren）**

- **目的**：人教（Ren Sect）日昌，薪火相继，生生不息。
- **愿景**：博古以丰己，启智而传薪；续人族文脉，继文明之火。

按年龄走一条路，也可以按自己的领域从浅到深。

## 这是什么

一个规划人生学习计划的**浅计划管理工具**：为一个人从幼儿到成年的人生旅程排计划、按计划学习，逐步丰富己身。

- **随年龄成长**：幼 → 小学（6–11）→ 初中、高中（12–17）→ 大学（18–20）→ 社会，年龄增加，学习的领域逐渐增多、逐层加深。
- **从被动到主动**：幼儿视角从被动接触这个世界的一切开始；随年龄增长转为主动学习自己感兴趣的领域和知识，最终主动去改变这个世界。
- **形成三观**：在完整、健康、科学的路径上逐步建立人生观、价值观、世界观，找到人生的终极目标——从哪里来，到哪里去。
- **人生导师**：提供科学规划，是一个人的人生旅程导师，帮助实现人生价值。

学习材料按年龄目录分开存放（幼儿 → 小学 → 中学 → 大学 → 社会）。学习记录与知识库保存在服务端（PostgreSQL），客户端本机只保留设备标识与最近一次成功数据的缓存，断网时用缓存启动、联网后自动同步；档案仍可导出本机副本。

## 平台支持

基于 Flutter，一套代码覆盖各端：

| 平台 | 状态 | 构建命令 / 产物 |
| --- | --- | --- |
| Windows 桌面 | ✅ 可构建运行 | `flutter build windows` → `app/build/windows/x64/runner/Release/study_app.exe` |
| 安卓 | ✅ CI 构建 APK | `flutter build apk --release` |
| iOS（苹果） | ✅ 工程已生成 | `flutter build ios`（需 macOS + Xcode） |
| Linux 桌面 | ✅ 工程可生成 | `flutter build linux`（需 Linux 桌面工具链） |

CI 目前自动构建 Android APK 与 Windows 包并上传 artifact；iOS/Linux 由本地或 macOS/Linux 机器构建。

## 仓库结构

```
study/
├── app/        Flutter 客户端（本机学习档案 + 幼儿触摸路线）
├── server/     素材服务（Fastify + PostgreSQL + S3 兼容对象存储）
├── doc/        分龄学习材料与设计文档（design.md、数据库使用说明.md 等）
└── .github/workflows/   Flutter CI / 构建 / 发布
```

| 目录 | 内容 |
| --- | --- |
| [doc/幼儿](doc/幼儿/目录.md) | 3–5 岁：触摸、语音、人来带路；识字、数、情绪、动手在同一条路线里 |
| [doc/小学](doc/小学/目录.md) | 6–11 岁：分科学习，6–8 岁与 9–11 岁题目不同 |
| [doc/中学](doc/中学/目录.md) | 12–17 岁：初中建立分科，高中学习原理和证据 |
| [doc/大学](doc/大学/目录.md) | 18–20 岁：通识、专业和一项做完的项目 |
| [doc/社会](doc/社会/目录.md) | 离开学校以后：公共文本、健康与科学，用在生活里 |

年龄档总览见 [doc/readme.md](doc/readme.md)，设计全文见 [doc/design.md](doc/design.md)，数据库用法见 [doc/数据库使用说明.md](doc/数据库使用说明.md)，开发进展记在 [doc/进展.md](doc/进展.md)。

## 一键启动开发环境（Windows）

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1
```

脚本会依次启动 Docker 中的 PostgreSQL 16 与 SeaweedFS（`server/docker-compose.yml`）、检查 Node 依赖并启动 Fastify API，再安装 Flutter 依赖并打开 Windows 应用。只有 API 的 `/healthz` 确认数据库和对象存储都正常后才会打开应用；任一强依赖失败都会显示红色错误并终止，不会带病继续启动。

前置要求：已安装并启动 Docker Desktop、Node.js ≥ 20；Flutter 之外无需 WSL 或本地数据库。

按需使用：

```powershell
# 只启动服务端，不打开桌面应用
powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1 -ServerOnly

# 启动前显式执行数据库迁移（日常启动默认不重复执行）
powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1 -Migrate
```

首次运行前需准备好 `server/.env`（`copy .env.example .env`，默认值与 `docker-compose.yml` 一致）。API 运行日志位于 `server/.dev-server.log` 和 `server/.dev-server.error.log`。

## 客户端 app/

Flutter 应用（`study_app`，中文名「文明重启」，英文名 Lumen），界面语言为简体中文，档案为本机 JSON，可导出副本。

主要模块：

| 模块 | 职责 |
| --- | --- |
| `lib/archive/` | 本机档案：练习记录、照护观察、导出副本 |
| `lib/profile/` | 本机档案配置（年龄档等） |
| `lib/plan/` | 学习计划：计划簿、计划文本、本地存储 |
| `lib/learning/` | 技能四档（尝试 → 熟悉 → 熟练 → 掌握）、阶梯、复习、成就 |
| `lib/knowledge/` | 知识图谱与分类树（父类/子类，全部来自服务端），按年龄档组织 |
| `lib/guardian/` | 监护人：照护观察记录与依据提醒（明确不是教师/心理咨询师/医生的判断） |
| `lib/ui/` | 页面与纸本风格主题：今日、路径、按兴趣看看、字库、复习等 |

### 运行

需要 Flutter 3.47.7（Dart 3.13.5），SDK 装在 `D:\flutter`；国内镜像用 `storage.flutter-io.cn`、`pub.flutter-io.cn`。

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d windows        # 桌面预览；也可 -d <device-id> 选安卓 / iOS / Linux
```

Windows 构建产物：`app/build/windows/x64/runner/Release/study_app.exe`。

### 测试

`app/test/` 下 8 个测试文件，覆盖档案、计划、技能阶梯、复习、知识图谱、监护人提醒与成就：

```powershell
cd app && flutter test
```

## 素材服务 server/

纸本学习应用的素材服务：PostgreSQL 存元数据与纯文本，SeaweedFS（S3 协议兼容，替代已停止维护的 MinIO）存图片/音频/视频本体，库里只存 `object_key`，内容通过预签名地址获取。

- 运行时：Node.js ≥ 20，TypeScript + Fastify 5 + zod 校验
- **权限**：普通用户只读；知识内容写接口（分类/知识/知识点/章节）与纠错审核仅管理员可用，未登录 401、普通用户 403。内置管理员 `admin/admin`，首次登录强制修改密码。评论、纠错提交与设备学习数据不要求登录。
- 配置集中在 `src/config.ts`，环境变量缺项直接报错，不带病启动
- 统一错误出口：`404`、`400` 参数错误、`413` 超限，响应形如 `{ error: { code, message } }`

### 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/healthz` | 健康检查（数据库 + 对象存储） |
| POST | `/api/auth/login` | 登录，返回会话 token 与用户信息（内置管理员 admin/admin，首登强制改密） |
| POST | `/api/auth/logout` | 退出登录（需 Bearer token） |
| GET | `/api/auth/me` | 当前登录用户 |
| POST | `/api/auth/password` | 修改自己的密码 |
| GET | `/api/users` | 用户列表（仅管理员） |
| PATCH | `/api/users/:id/role` | 调整用户角色 user/admin（仅管理员） |
| POST | `/api/users/:id/reset-password` | 重置他人密码为临时密码（仅管理员） |
| GET | `/api/degree` | 当前用户境界（九境三阶） |
| POST | `/api/degree/applications` | 提交学位申请（同用户同时只允许一条待审） |
| GET | `/api/degree/applications/mine` | 我的申请记录 |
| GET | `/api/degree/applications` | 申请列表（仅管理员，`status=pending` 等） |
| POST | `/api/degree/applications/:id/review` | 审核学位申请，通过即提升境界（仅管理员） |
| POST | `/api/assets/text` | 新建纯文本素材（正文直接入库） |
| POST | `/api/assets` | 上传图片/音频/视频（multipart） |
| GET | `/api/assets` | 列表，支持 `kind`、`limit`、`offset` |
| GET | `/api/assets/:id` | 素材详情 |
| GET | `/api/assets/:id/content` | 取内容（文本回正文，二进制返回预签名地址） |
| DELETE | `/api/assets/:id` | 删除素材 |
| GET | `/api/knowledge` | 知识库整包：分类树（父类/子类）、概念、分龄呈现、知识点、章节、sageCredits |
| POST | `/api/knowledge/categories` | 新建分类/子类（`parentId` 可嵌套；未迁移时 503 `migration_required`） |
| PATCH | `/api/knowledge/categories/:id` | 分类改名 |
| POST | `/api/knowledge/concepts` | 新建知识（事务：概念 + 分龄呈现 + 三档知识点） |
| POST | `/api/knowledge/points` | 追加知识点 |
| GET/POST/PUT/DELETE | `/api/knowledge/points/chapters` | 知识点章节 CRUD（按概念+年龄段+程度+位置定位） |
| GET/POST | `/api/knowledge/points/comments` | 知识点评论 |
| GET/POST | `/api/knowledge/points/corrections` | 纠错提交与列表 |
| GET | `/api/knowledge/points/corrections/pending` | 待审核纠错列表 |
| POST | `/api/knowledge/points/corrections/review` | 审核纠错（通过发积分） |
| GET | `/api/knowledge/points/credits` | 积分余额与流水 |
| GET/PUT | `/api/devices/:deviceId/sage` | 智者名读取/保存 |
| POST | `/api/devices/:deviceId/sage/contributions` | 智者贡献（提交即审批） |
| GET/PUT | `/api/devices/:deviceId/data` | 设备数据整包读写（事务内替换 + 知识引用校验） |

### 运行

```powershell
# 1. 起依赖（PostgreSQL 16 + SeaweedFS）
cd server
docker compose up -d

# 2. 配置
copy .env.example .env        # 默认值与 docker-compose.yml 一致

# 3. 建表并启动
npm install
npm run db:migrate
npm run dev                   # http://127.0.0.1:3000
```

其他脚本：

```powershell
npm run typecheck    # tsc --noEmit
npm run build        # tsc 编译到 dist/
npm start            # 运行 dist/index.js
```

主要环境变量（完整见 [server/.env.example](server/.env.example)）：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `3000` | 服务端口 |
| `DATABASE_URL` | `postgres://study:...@127.0.0.1:5432/study` | PostgreSQL 连接串 |
| `S3_ENDPOINT` | `http://127.0.0.1:9000` | SeaweedFS S3 地址 |
| `S3_BUCKET` | `study-assets` | 桶名（启动时自动创建） |
| `MAX_UPLOAD_MB` | `50` | 单文件上限 |
| `SIGNED_URL_TTL_SECONDS` | `900` | 预签名地址有效期 |
| `CORS_ORIGIN` | `*` | 跨域来源，多个用逗号分隔 |

## 持续集成

`.github/workflows/` 下三个工作流，Flutter 版本统一为 `3.47.7`：

| 工作流 | 触发 | 作用 |
| --- | --- | --- |
| `flutter-ci.yml` | `main` 的 push / PR（`app/**` 变更） | 复用构建工作流做检查 |
| `flutter-build.yml` | 被引用 | 分析测试 + Android APK + Windows 包，产物上传为 artifact |
| `flutter-release.yml` | 推送 `v*` 标签 | 先校验标签号与 `app/pubspec.yaml` 的 `version` 一致，再构建并发布 Release |

## 设计要点

- **学习数据在服务端、缓存在本机**：记录与知识库存 PostgreSQL，客户端只留设备标识与缓存，断网可用、联网自动同步；档案可导出本机副本，不上传给第三方。
- **两级角色**：普通用户登录后只读；管理员可修改添加一切知识内容并审核纠错。详见 [doc/开发指导文档.md](doc/开发指导文档.md) 的「管理体系」。
- **技能四档**：尝试 → 熟悉 → 熟练 → 掌握（规划中的认知四档「入门/熟练/精通/创造」见 [doc/开发指导文档.md](doc/开发指导文档.md)），同一技能在不同题目里稳定使用才升级；不进排行。
- **两句才记成长**：「我更能做成事了」与「我更知道自己是谁了」同时发生才记成成长。
- **一个年龄一套学法**：3–5 岁用触摸和语音，6 岁起文字菜单分科学习，12 岁起学概念与出处。
- **没有连胜、排行榜、课内购买和广告**；答错说明错在哪，并给一次改的机会。

完整理念、三对张力与动画约定见 [doc/design.md](doc/design.md)。
