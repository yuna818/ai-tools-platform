# syntax=docker/dockerfile:1
# ai-tools-platform — Railway 单服务部署
# 结构：前端 Vue build 出来的 dist 由 Flask 自己托管（backend/app/__init__.py
# 里的 serve_frontend 会读 frontend/dist），所以一个服务就够了，
# 不用再单独起前端服务。前端调的 /api/v1 也是同源，不用配 CORS / 代理。
#
# 构建分两段：
#   1. node:24 先把 frontend build 成 dist
#   2. python:3.12 再装后端依赖，并把 dist 拷进来一起跑

# ---------- Stage 1: build frontend ----------
FROM node:24-alpine AS frontend-build
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ---------- Stage 2: backend runtime ----------
FROM python:3.12-slim AS runtime
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_ENV=production \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# bcrypt / cryptography 需要编译
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc libffi-dev python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install -r backend/requirements.txt \
    && pip install "gunicorn==22.0.0"

# 后端代码 + 数据库 SQL + 启动脚本
COPY backend/ ./backend/
COPY database/ ./database/
COPY run_migrations.py ./
COPY scripts/ ./scripts/
RUN chmod +x scripts/railway-start.sh

# 前端 build 产物：Flask 按 backend/../frontend/dist 这个相对路径找它
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

# Railway 会注入 $PORT，start 脚本会把它转成 FLASK_PORT
EXPOSE 5000
CMD ["bash", "scripts/railway-start.sh"]
