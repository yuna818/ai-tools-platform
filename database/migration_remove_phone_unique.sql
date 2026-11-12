-- 移除 phone 唯一约束，允许邮箱注册时 phone 为空
ALTER TABLE t_user DROP INDEX uk_phone;

-- 为 email 添加普通索引（非唯一，由应用层做唯一性校验）
ALTER TABLE t_user ADD INDEX idx_email (email);
