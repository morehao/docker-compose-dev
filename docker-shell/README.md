# docker-shell

命令如下：
``` bash
docker cp ./shell/*.sh mysql8:/tmp
docker cp ./shell/*.sql mysql8:/tmp
docker exec -it mysql8 /bin/bash

# 在 mysql8 容器中的操作
cd /tmp
chmod +x ./run_sql.sh
bash-5.1# ./run_sql.sh user root 123456 demo
Executing SQL:
INSERT INTO user (
    `company_id`,
    `department_id`,
    `name`,
    `created_by`,
    `updated_by`,
    `deleted_by`
) VALUES (
    101,
    5,
    '张三',
    1,
    1,
    0
);
mysql: [Warning] Using a password on the command line interface can be insecure.
SQL executed successfully.
```
