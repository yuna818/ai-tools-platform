#!/usr/bin/env bash
# Railway 启动脚本：等 MySQL 就绪 -> 建库建表 -> 跑迁移 -> 起 Flask
# 由 railway.json 的 startCommand 调用，也可作 Dockerfile 的 CMD。
set -e

cd "$(dirname "$0")/.."

# --- Railway MySQL 插件给的变量名和这个项目要的不一样，做一次映射 ---
# Railway:  MYSQLHOST / MYSQLPORT / MYSQLUSER / MYSQLPASSWORD / MYSQLDATABASE
# 项目要:   MYSQL_HOST / MYSQL_DB_PORT / MYSQL_DB_USER / MYSQL_DB_PASSWORD / MYSQL_DB_NAME
# 只有在项目自己的变量没填时才用 Railway 的，避免覆盖你在面板里手动填的值。
export MYSQL_HOST="${MYSQL_HOST:-${MYSQLHOST:-127.0.0.1}}"
export MYSQL_DB_PORT="${MYSQL_DB_PORT:-${MYSQLPORT:-3306}}"
export MYSQL_DB_USER="${MYSQL_DB_USER:-${MYSQLUSER:-ai_user}}"
export MYSQL_DB_PASSWORD="${MYSQL_DB_PASSWORD:-${MYSQLPASSWORD:-}}"
export MYSQL_DB_NAME="${MYSQL_DB_NAME:-${MYSQLDATABASE:-ai_tools_platform}}"

# Railway 注入的端口（没注入就默认 5000，和本地一样）
export FLASK_PORT="${PORT:-5000}"
export FLASK_ENV="${FLASK_ENV:-production}"

if [ -z "$SECRET_KEY" ] || [ -z "$JWT_SECRET_KEY" ]; then
  echo "ERROR: SECRET_KEY and JWT_SECRET_KEY must be set in Railway Variables (production refuses to start without them)."
  exit 1
fi
if [ -z "$DEEPSEEK_API_KEY" ] && [ -z "$GEMINI_API_KEY" ]; then
  echo "WARNING: neither DEEPSEEK_API_KEY nor GEMINI_API_KEY is set — the site will open, but chat will fail. Set one in Railway Variables."
fi

# --- 等 MySQL ---
echo "Waiting for MySQL at ${MYSQL_HOST}:${MYSQL_DB_PORT} ..."
python3 - <<'PY'
import os, sys, time
import pymysql
host = os.environ["MYSQL_HOST"]
port = int(os.environ["MYSQL_DB_PORT"])
user = os.environ["MYSQL_DB_USER"]
password = os.environ["MYSQL_DB_PASSWORD"]
for i in range(60):
    try:
        conn = pymysql.connect(host=host, port=port, user=user, password=password, connect_timeout=5)
        conn.close()
        print("MySQL is up.")
        break
    except Exception as exc:
        print(f"MySQL not ready ({i+1}/60): {exc}")
        time.sleep(5)
else:
    print("ERROR: MySQL did not become ready in 300s.")
    sys.exit(1)
PY

# --- 建库 + 建表（init.sql，幂等：表已存在会跳过）---
echo "Initialising database schema..."
python3 scripts/railway-init-db.py

# --- 跑迁移（run_migrations.py，migration_*.sql，幂等）---
echo "Running migrations..."
python3 run_migrations.py

# --- 起服务 ---
# gthread：聊天是 SSE 流式输出，长连接会占一个 worker，线程模式比同步模式稳。
echo "Starting backend on 0.0.0.0:${FLASK_PORT} ..."
exec gunicorn --chdir backend \
  --workers 2 --threads 4 --worker-class gthread \
  --timeout 120 --bind "0.0.0.0:${FLASK_PORT}" \
  run:app
