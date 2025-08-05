#!/bin/bash

# 用法提示
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <table_name> <mysql_user> <mysql_password> [database_name=test_db]"
  echo "Example: $0 users root 123456 mydb"
  exit 1
fi

TABLE_NAME=$1
MYSQL_USER=$2
MYSQL_PASSWORD=$3
DATABASE_NAME=${4:-test_db}  # 默认使用 test_db

# 检查模板文件是否存在
if [ ! -f "template.sql" ]; then
  echo "Error: template.sql file not found!"
  exit 1
fi

# 构建 SQL（用 envsubst 替换变量）
declare -A vars=(
  [TABLE_NAME]="$TABLE_NAME"
)

SQL=$(<template.sql)
for key in "${!vars[@]}"; do
  SQL="${SQL//\$\{$key\}/${vars[$key]}}"
done

echo "Executing SQL:"
echo "$SQL"

# 执行 SQL
if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DATABASE_NAME" -e "$SQL"; then
  echo "Error: Failed to execute SQL!"
  exit 1
fi

echo "SQL executed successfully."