-- 把 ai-tools-platform 的默认 AI 提供商改成 Groq（免费）。
--
-- 用法：在 Railway MySQL 的 Query / SQL 执行里跑这份文件。
-- 先把下面 __GROQ_KEY__ 换成你的真实 Groq Key（gsk_ 开头）。
-- 注意：跑完不要把带真实 Key 的文件提交到 GitHub。
--
-- 背景：项目启动时 bootstrap 会把 deepseek / openai / gemini 三个提供商
-- 都写进 t_ai_provider，而且默认用排第一位的 deepseek。
-- 光在 Railway 环境变量里填 Groq 是不够的，还要把 deepseek / gemini
-- 停用，并把 openai 这一路的地址和 Key 指到 Groq，否则聊天默认还是走
-- DeepSeek，会报“未配置 DeepSeek API Key”。
-- 这份 SQL 就是做这件事，重复跑是安全的。

USE ai_tools_platform;

-- 1. 停用 DeepSeek 和 Gemini，只留 openai（Groq）启用
UPDATE t_ai_provider SET is_active = 0 WHERE `key` IN ('deepseek', 'gemini');

-- 2. 把 openai 这一路指到 Groq
UPDATE t_ai_provider
SET base_url = 'https://api.groq.com/openai/v1',
    api_key  = '__GROQ_KEY__',
    adapter  = 'openai',
    is_active = 1,
    sort_order = 1
WHERE `key` = 'openai';

-- 3. 把 openai 下面其它模型的默认标记清掉，再把 Qwen 设为默认模型
--    如果 Groq 控制台显示 Qwen 的模型名不是 qwen/qwen3.8-27b，
--    把下面两处都改成控制台当时显示的名字（比如 qwen/qwen3.8-27b）。
UPDATE t_ai_model m
JOIN t_ai_provider p ON p.id = m.provider_id
SET m.is_default = 0
WHERE p.`key` = 'openai';

INSERT INTO t_ai_model (provider_id, model_id, display_name, is_active, is_default, sort_order)
SELECT id, 'qwen/qwen3.8-27b', 'Qwen3 27B (Groq 免费)', 1, 1, 0
FROM t_ai_provider WHERE `key` = 'openai'
ON DUPLICATE KEY UPDATE is_active = 1, is_default = 1, display_name = 'Qwen3 27B (Groq 免费)';

-- 4. 检查：跑完应该只看到 openai 这一行是 is_active=1
SELECT `key`, name, adapter, base_url, is_active, sort_order FROM t_ai_provider ORDER BY sort_order;
SELECT p.`key` AS provider, m.model_id, m.display_name, m.is_default, m.is_active
FROM t_ai_model m JOIN t_ai_provider p ON p.id = m.provider_id
WHERE p.`key` = 'openai';
