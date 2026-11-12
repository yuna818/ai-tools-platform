"""Railway 首次启动建库脚本：建库 + 跑 database/init.sql。

只做这两件事，不跑 seed.sql：
- init.sql 里全是 `CREATE TABLE IF NOT EXISTS`，重复跑是安全的；
- seed.sql 会插一个密码公开的演示账号（Test123456），上线不要自动跑，
  需要的话以后手动在 Railway MySQL 里执行一次。

run_migrations.py 只跑 migration_*.sql，不管 init.sql，
所以启动脚本要先跑这个，再跑 run_migrations.py。
"""
import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
HOST = os.environ.get("MYSQL_HOST", "127.0.0.1")
PORT = int(os.environ.get("MYSQL_DB_PORT", "3306"))
USER = os.environ.get("MYSQL_DB_USER", "ai_user")
PASSWORD = os.environ.get("MYSQL_DB_PASSWORD", "")
DB = os.environ.get("MYSQL_DB_NAME", "ai_tools_platform")


def split_statements(sql: str):
    """按分号切，再去掉每条语句开头的 -- / # 注释行。
    init.sql 里很多 CREATE TABLE 前面都带一句 -- 注释，
    不去掉的话，PyMySQL 会把整段当注释执行，导致建表被跳过。
    init.sql 里没有触发器 / 存储过程，也没有分号在字符串里，可以这样切。"""
    for stmt in sql.split(";"):
        lines = [
            line for line in stmt.splitlines()
            if line.strip() and not line.strip().startswith(("--", "#"))
        ]
        stmt = "\n".join(lines).strip()
        if stmt:
            yield stmt


def main() -> None:
    # 1. 先不指定库连上，建库（库已存在也不报错）
    conn = pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD, charset="utf8mb4"
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                f"CREATE DATABASE IF NOT EXISTS `{DB}` "
                "DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci"
            )
        conn.commit()
        print(f"Database `{DB}` ready.")
    finally:
        conn.close()

    # 2. 连上库，跑 init.sql
    init_sql = (ROOT / "database" / "init.sql").read_text(encoding="utf-8")
    conn = pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD,
        database=DB, charset="utf8mb4",
    )
    try:
        with conn.cursor() as cur:
            for stmt in split_statements(init_sql):
                cur.execute(stmt)
        conn.commit()
        print("init.sql applied.")
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - 启动失败要让 Railway 看到明确报错
        print(f"ERROR: database init failed: {exc}", file=sys.stderr)
        raise
