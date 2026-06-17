#!/bin/sh
if [ ! -f /data/gitea/.initialized ]; then
  mkdir -p /data/gitea/conf /data/gitea/log /data/git/repositories /data/git/lfs /data/git/.ssh
  cat > /data/gitea/conf/app.ini << 'GITEA_EOF'
APP_NAME = Gitea: Git with a cup of tea
RUN_MODE = prod

[repository]
ROOT = /data/git/repositories

[repository.local]
LOCAL_COPY_PATH = /data/gitea/tmp/local-repo

[repository.upload]
TEMP_PATH = /data/gitea/uploads

[server]
APP_DATA_PATH = /data/gitea
DOMAIN = ${GITEA_DOMAIN}
SSH_DOMAIN = localhost
HTTP_PORT = 3009
ROOT_URL = http://${GITEA_DOMAIN}:3009
DISABLE_SSH = true
SSH_PORT = 22
SSH_LISTEN_PORT = 22
LFS_START_SERVER = false

[database]
PATH = /data/gitea/gitea.db
DB_TYPE = sqlite3
LOG_SQL = false

[indexer]
ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve

[session]
PROVIDER_CONFIG = /data/gitea/sessions

[picture]
AVATAR_UPLOAD_PATH = /data/gitea/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars

[attachment]
PATH = /data/gitea/attachments

[log]
MODE = console
LEVEL = info
ROOT_PATH = /data/gitea/log

[security]
INSTALL_LOCK = true

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false

[lfs]
PATH = /data/git/lfs
GITEA_EOF
  chown -R git:git /data /data/git
  su git -c "/usr/local/bin/gitea migrate"
  su git -c "/usr/local/bin/gitea admin user create --username admin --password ${GITEA_ADMIN_PASSWORD} --email admin@example.com --admin"
  touch /data/gitea/.initialized
  chown git:git /data/gitea/.initialized
fi
exec /usr/bin/entrypoint