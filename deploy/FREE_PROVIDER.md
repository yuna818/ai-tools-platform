# 免费方案：不用 DeepSeek Key，也能聊天（Groq 主推，OpenRouter 备用）

> 结论先说：**不用改项目一行代码**。这个项目的 OpenAI 适配器本来就是
> OpenAI 兼容口，作者自己在代码注释里写了：任何 OpenAI 兼容服务，
> 只要把 `OPENAI_API_BASE` 指过去就能用。
> 所以免费方案就是：把 `openai` 这一路的地址和 Key，换成 Groq / OpenRouter 的。

## 主推：Groq（免费，不用信用卡）

### 为什么选它

|  | Groq 免费档 | OpenRouter 免费档 |
|---|---|---|
| 每天能聊多少 | 大模型每天 1,000 次请求、每天 20 万 token | 每天只有 50 次请求（没充过 $10 的话） |
| 每分钟 | 30 次 | 20 次 |
| 要不要卡 | 不要 | 不要 |
| 速度 | 非常快，号称每秒几百 token | 看模型，有排队 |

OpenRouter 那个每天 50 次，一场长剧情聊下来很快就用完了，
所以 Groq 是主推，OpenRouter 只当备用。

### 拿 Key（2 分钟）

1. 打开 console.groq.com，用邮箱 / GitHub / Google 登录；
2. 左侧 **API Keys → Create API Key**，名字随便填，比如 `ai-tools-platform`；
3. 复制那串以 `gsk_` 开头的 Key，**只粘贴到 Railway 的 Variables 里，别发到聊天里，也别提交到 GitHub**。

### 填到 Railway（在后端服务的 Variables 里）

| 变量 | 填什么 |
|---|---|
| `OPENAI_API_BASE` | `https://api.groq.com/openai/v1` |
| `OPENAI_API_KEY` | 你的 Groq Key（`gsk_...`） |
| `OPENAI_CHAT_MODEL` | `qwen/qwen3.8-27b` |
| `DEFAULT_AI_PROVIDER` | `openai` |
| `FLASK_ENV` | `production` |
| `SECRET_KEY` / `JWT_SECRET_KEY` | 两串不一样的随机字符串（和原来一样必填） |

**不用填 `DEEPSEEK_API_KEY` 了**，留空就行。

### 模型选哪个

- **首选 `qwen/qwen3.8-27b`**：中文最好，写中文小说、长剧情最顺。
  2026-11-12 用 Luna 的 Key 实测过：Key 有效，这个模型能正常回话，
  写成人剧情也没有拒答。注意旧名字 `qwen/qwen3-32b` 已经不存在了，
  填它会报 `model_not_found`。
  如果以后部署报 `model_not_found`，说明 Groq 又改了模型名，
  去 Groq 控制台的 Limits 页看一眼当前在免费档里的 Qwen 模型叫什么，
  改一下 `OPENAI_CHAT_MODEL` 再重新部署就行。
- **备选 `openai/gpt-oss-120b`**：个头最大，质量最好，但它是 OpenAI 的
  开源模型，尺度上可能比 Qwen 保守，写成人剧情时更容易“拒答”或绕开。
  Qwen 不行了再换它试试。

### 最关键的一步：让它变成默认提供商

这个项目启动时，会把环境变量里的三个提供商（DeepSeek / OpenAI / Gemini）
都写进数据库 `t_ai_provider`，而且**默认用排第一位的那个，也就是 DeepSeek**。
你光填了 Groq 的变量、没做这一步，聊天还是会默认走 DeepSeek，
然后报“没配 DeepSeek Key”。

部署成功、能打开网站之后，二选一：

**方法 A（推荐，不用碰数据库）：在网站后台关掉 DeepSeek 和 Gemini**

1. 用你注册的账号登录，进管理后台 / AI 提供商管理；
2. 把 `deepseek` 和 `gemini` 两个提供商设为停用（is_active 关掉），
   只留 `openai`（也就是 Groq）启用；
3. 聊天页的提供商下拉框里选 `openai` / Qwen 模型，再发一句话试试。

**方法 B：直接改数据库**

在 Railway 的 MySQL 里执行 `deploy/seed-free-provider.sql`（先把里面的
`__GROQ_KEY__` 换成你的真实 Key，**改完不要把带 Key 的文件提交到 GitHub**）。
它做的事就是：停用 deepseek/gemini，把 openai 这一路的地址、Key 改成 Groq，
并把 Qwen 模型设为默认。执行完重启一次后端服务。

### 免费档的上限，提前知道

- 每天 20 万 token：按一轮对话来回几千 token 算，一天聊几十轮没问题，
  但别拿它当无限量刷，超了会报 429，等第二天恢复。
- 每分钟 8,000 token：一次回太长、上下文攒太长时会先撞到这个，
  表现就是偶尔一次报错，重发一次就好。
- 模型名单会变：Groq 免费档里的模型几个月就会换一批，
  哪天 Qwen 下了免费档，就按上面“备选”换一个，或者去控制台看最新名单。

## 备用：OpenRouter（免费，但每天只有 50 次）

如果 Groq 当天被限流、或者你想换个口味，可以再备一个 OpenRouter：

1. 打开 openrouter.ai，登录后在 Keys 里建一个 Key，不用绑卡；
2. Railway 里把上面那三个变量改成：
   - `OPENAI_API_BASE` = `https://openrouter.ai/api/v1`
   - `OPENAI_API_KEY` = 你的 OpenRouter Key
   - `OPENAI_CHAT_MODEL` = `nousresearch/hermes-3-llama-3.1-70b:free`
3. 重新部署。

为什么选 Hermes 3 而不是 DeepSeek 免费版：
- DeepSeek 的免费版在 OpenRouter 上时有时无，`deepseek/deepseek-chat-v3-0324:free`
  在 2026-10-30 的实测里已经没有免费端点了，别照着旧教程抄；
- Hermes 3 是专门为角色扮演调过的开源模型，实测里“最听话、最不说教”，
  对成人剧情的拒答率很低，适合这个项目；
- 代价就是每天 50 次请求（没充过 $10 的话），充过 $10 一次之后变成每天 1,000 次，
  但那就不是纯免费了。

## 免费方案的实话

- **没法保证尺度**：Groq 和 OpenRouter 上的免费模型都是开源模型，
  自带不同程度的安全调教。Qwen 写成人剧情一般能写，但偶尔会拒答或写得很含蓄；
  如果它总拒，换 Hermes 3 或 gpt-oss-120b 试试，再不行就只能回 DeepSeek 付费那条路。
- **没法保证长期免费**：免费档的模型名单、限额几个月就变一次，
  这份说明写的是 2026-11-12 查到的情况，部署时以 Groq / OpenRouter
  控制台当时显示的为准。
- **这台机器上没法帮你实测**：我没有你的 Groq Key，也没法替你注册，
  所以端到端（注册 → 选模型 → 发一句话 → 收到回复 → 状态栏变化）
  要你部署完、填好 Key 之后自己试一次，报错了把 Railway 日志里那段
  `OpenAI 调用失败 [xxx]` 发给我，我再帮你调。

## 和 DeepSeek 付费方案的对比

|  | DeepSeek（付费） | Groq（免费） | OpenRouter 免费 |
|---|---|---|---|
| 费用 | 充 $2 起，Flash 输出约 $0.66–1.32 / 百万 token | $0 | $0 |
| 每天量 | 看余额，基本够用 | 1,000 次 / 20 万 token | 50 次 |
| 中文 | 最好 | Qwen 很好 | Hermes 3 中文一般 |
| 成人尺度 | 最稳 | 偶尔拒答 | Hermes 3 最放得开 |
| 稳定性 | 最稳 | 模型名单会变 | 免费模型时有时无 |
