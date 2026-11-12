# Railway 云端部署（ai-tools-platform）

> 目标：把这个项目放到 Railway 上，手机打开链接就能玩。
> 结构是**一个服务**就够了：前端 Vue build 出来的 `dist` 由 Flask 自己托管，
> 前端调的 `/api/v1` 也是同源，不用再单独起前端服务。
> 数据库用 Railway 的 MySQL 插件。

## 你要先准备好的 3 样东西

| 东西 | 去哪弄 | 说明 |
|---|---|---|
| GitHub 账号 + 一个 Fork | github.com | Railway 要从你的仓库拉代码，不能直接连原作者的仓库部署你自己的改动 |
| Railway 账号 | railway.app，用 GitHub 登录 | 免费额度很小，长期玩要绑卡 / 付费，大概每月几美元起 |
| AI 的 Key（二选一） | DeepSeek：platform.deepseek.com，注册、充值后在 API Keys 里创建 | **没有它网站能打开，但聊天会失败**。这是最关键的一步，Key 别发在聊天里 |
| 免费替代：Groq Key | console.groq.com，登录后在 API Keys 里创建，不用信用卡、不用充值 | **主推的免费方案**，详见 `deploy/FREE_PROVIDER.md`：把 `openai` 这一路的地址和 Key 换成 Groq 就行，不用改代码，也不用 DeepSeek Key |

## 部署步骤（按顺序做）

### 1. Fork 这个仓库到你自己的 GitHub

打开 https://github.com/shinkiyuusei/ai-tools-platform ，右上角 **Fork**，
Fork 到你自己的账号下。

> 这一步必须做：Railway 部署要连你自己的仓库，
> 下面加的 `Dockerfile` / `railway.json` / `scripts/railway-start.sh`
> 也要先合进你 Fork 的仓库里才能生效。
> 做法：把我这边 `~/workspace/ai-tools-platform` 里新增的这几个文件，
> 复制到你 Fork 的仓库根目录，commit + push。
> 新增的文件只有这 5 个，没有改原项目任何一行代码：
> `Dockerfile`、`railway.json`、`.dockerignore`、
> `scripts/railway-start.sh`、`scripts/railway-init-db.py`，外加这份说明。

### 2. Railway 新建项目，从 GitHub 部署

1. 打开 railway.app，用 GitHub 登录。
2. **New Project → Deploy from GitHub repo**，选你刚 Fork 的 `ai-tools-platform`。
3. Railway 会读到根目录的 `railway.json` 和 `Dockerfile`，自动用 Dockerfile 构建。
   第一次构建要几分钟（要装 Python 依赖 + `npm ci` + 前端 build），
   看到构建日志卡在某一步超过 10 分钟，先别急，等它跑完。

### 3. 加一个 MySQL

1. 在同一个 Project 里点 **New → Database → Add MySQL**。
2. 等 MySQL 的状态变成 Running。
3. 回到后端服务（ai-tools-platform 那个服务）→ **Variables**，
   把 MySQL 的变量引用加进去。Railway 的 MySQL 插件会自动给这些变量：
   `MYSQLHOST`、`MYSQLPORT`、`MYSQLUSER`、`MYSQLPASSWORD`、`MYSQLDATABASE`。
   启动脚本会自动把它们转成项目要的
   `MYSQL_HOST` / `MYSQL_DB_PORT` / `MYSQL_DB_USER` /
   `MYSQL_DB_PASSWORD` / `MYSQL_DB_NAME`，你不用手动一个个抄。
   如果你想手动填，也可以用 Railway 的引用写法：
   `MYSQL_HOST = ${{MySQL.MYSQLHOST}}`，以此类推。

### 4. 填环境变量（在后端服务的 Variables 里）

**走 DeepSeek 付费（原来那条路），必填：**

| 变量 | 填什么 |
|---|---|
| `SECRET_KEY` | 随便一串长的随机字符串，比如用 `openssl rand -hex 32` 生成的 |
| `JWT_SECRET_KEY` | 再来一串，和上面不一样的随机字符串 |
| `DEEPSEEK_API_KEY` | 你的 DeepSeek Key（以 `sk-` 开头的那串） |
| `FLASK_ENV` | `production` |
| `DEFAULT_AI_PROVIDER` | `deepseek` |

**走 Groq 免费（现在主推），必填——`DEEPSEEK_API_KEY` 不用填了：**

| 变量 | 填什么 |
|---|---|
| `SECRET_KEY` / `JWT_SECRET_KEY` | 同上，两串不一样的随机字符串 |
| `OPENAI_API_BASE` | `https://api.groq.com/openai/v1` |
| `OPENAI_API_KEY` | 你的 Groq Key（以 `gsk_` 开头的那串） |
| `OPENAI_CHAT_MODEL` | `qwen/qwen3.8-27b` |
| `FLASK_ENV` | `production` |
| `DEFAULT_AI_PROVIDER` | `openai` |

> 免费方案还有一步不能省：部署成功后，要去后台把 DeepSeek / Gemini
> 两个提供商停用，只留 `openai`（Groq），否则聊天默认还是走 DeepSeek。
> 完整步骤、模型备选、限额和备用 OpenRouter 方案都在
> `deploy/FREE_PROVIDER.md` 里，SQL 在 `deploy/seed-free-provider.sql`。

**可不填，有默认值：**

| 变量 | 默认值 |
|---|---|
| `DEEPSEEK_API_BASE` | `https://api.deepseek.com` |
| `DEEPSEEK_CHAT_MODEL` | `deepseek-v4-flash` |
| `DEEPSEEK_REASONER_MODEL` | `deepseek-v4-pro` |

> 注意：不要把这些 Key 写进代码 / 提交到 GitHub，
> 只填在 Railway 面板的 Variables 里。

### 5. 生成访问链接，打开测试

1. 后端服务 → **Settings → Networking → Generate Domain**，
   会给你一个 `https://xxx.up.railway.app` 的链接。
2. 打开它，应该能看到首页。
3. 先点右上角注册一个账号（这是你自己的站，注册的第一个号就是你的号），
   再随便建一个世界观 / 角色，发一句话，看能不能收到 AI 回复，
   再看状态栏的好感度 / 欲望值有没有变。
4. 如果首页能打开但聊天报错，先看第 6 节，大概率是 Key 或 MySQL 的问题。

## 启动时自动做的事

每次服务启动，`scripts/railway-start.sh` 会按顺序做：

1. 把 Railway 的 `MYSQLHOST` 等变量转成项目要的名字；
2. 等 MySQL 就绪（最多等 300 秒）；
3. `scripts/railway-init-db.py`：建库 + 跑 `database/init.sql` 建表
   （全是 `CREATE TABLE IF NOT EXISTS`，重复跑是安全的）；
4. `python run_migrations.py`：跑 `database/migration_*.sql`；
5. 用 gunicorn 起 Flask，监听 Railway 给的 `$PORT`，
   健康检查是 `GET /health`。

**不会自动跑 `database/seed.sql`。** 那个文件会插一个密码公开的演示账号
（`demo@example.com` / `Test123456`），上线不要自动跑。
想要演示数据，以后再手动在 Railway MySQL 里执行一次。

## 常见问题

| 现象 | 原因 / 办法 |
|---|---|
| 服务起不来，日志说 `SECRET_KEY is not set` | `FLASK_ENV=production` 时必须填 `SECRET_KEY` 和 `JWT_SECRET_KEY`，回第 4 步补上，重新部署 |
| 首页能打开，聊天报错 / 没回复 | 先看日志里 DeepSeek 有没有返回 401：401 就是 Key 错了 / 没充值 / 没余额；换个 Key 再试 |
| 走 Groq 免费，聊天报 `未配置 DeepSeek API Key` | 默认提供商还是 DeepSeek，没切到 openai。去后台停用 deepseek/gemini，只留 openai，或跑 `deploy/seed-free-provider.sql`，再重启后端，详见 `deploy/FREE_PROVIDER.md` |
| 走 Groq，报 `model_not_found` / 404 | Groq 把那个模型下架改名了。去 Groq 控制台 Limits 页看当前免费档里的 Qwen 模型名，改 `OPENAI_CHAT_MODEL` 再重新部署 |
| 走 Groq，报 429 | 当天 20 万 token 或 1,000 次用完了，等第二天恢复；或者切到 OpenRouter 备用（每天 50 次） |
| 日志说连不上 MySQL | MySQL 服务还没 Running，或者后端服务和 MySQL 不在同一个 Project 里；等 MySQL 变绿再重新部署一次后端 |
| 构建失败，卡在 `npm ci` / `pip install` | 一般是网络抖动，点 Redeploy 再试一次；反复失败把构建日志发给我看 |
| 打开是空白页 | 看浏览器控制台是不是 `/api/v1/...` 404：前端 `dist` 没 build 出来，先看 Dockerfile 的前端构建那段有没有报错 |
| 免费额度用完了，服务停了 | Railway 免费额度很小，绑卡后按量计费；不想续费就改回本地跑，或者换 VPS |

## 费用提醒

- Railway 没有长期免费的套餐，免费额度用完就停，之后按实际用量收费，
  一个人玩的话，一个月通常是几美元到十几美元，主要花在 MySQL 和后端一直开着。
- DeepSeek 的费用是另外算的，按 token 收，你在 DeepSeek 后台充值、看用量，
  不走 Railway 的账单。

## 本地验证过什么（在我这台机器上）

- 仓库已 clone 到 `~/workspace/ai-tools-platform`，README / 配置 / 启动方式都核对过；
- 确认了后端用 `MYSQL_HOST` 等变量、前端用相对路径 `/api/v1`、
  Flask 会自己托管 `frontend/dist`，所以单服务部署是可行的；
- 确认了 `run_migrations.py` 不管 `init.sql`，所以启动脚本里先跑了建库建表，
  再跑迁移；
- **没有在本地真正跑通全套**：这台机器没有 Docker / MySQL，
  而且 DeepSeek Key 还没填，所以本地验证只做到“文件和逻辑都对得上”，
  真正的端到端验证要在 Railway 上部署成功、填好 Key 之后才算数。
- 免费方案（2026-11-12 新增）核对过：OpenAI 适配器就是 OpenAI 兼容口，
  作者注释里写了任何 OpenAI 兼容服务只要改 `OPENAI_API_BASE` 就能用；
  启动时会把三个提供商写进 `t_ai_provider`，默认取排第一位的 DeepSeek，
  所以免费方案必须多做一步停用 DeepSeek/Gemini、只留 openai，
  这一步写在 `deploy/FREE_PROVIDER.md` 和 `deploy/seed-free-provider.sql` 里。
  Groq / OpenRouter 的免费模型名单和限额以部署时控制台为准，没法在这边实测。
