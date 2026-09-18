#!/usr/bin/env python3
"""RustFS 策略（canned policy）管理小工具 —— 只用 Python 标准库。

为什么不用 mc：MinIO 已归档，`dl.min.io` 停止分发 `mc`（HTTP 410），homebrew 的 `minio-mc`
也已标记 deprecated。本脚本直接对 RustFS 的 MinIO 兼容 admin API（`/rustfs/admin/v3/*`）
做 AWS SigV4 签名，够用且零依赖。

用法（在本目录下执行）：
  python3 rustfs_policy.py list                     # 列出全部策略名与 Action
  python3 rustfs_policy.py show iam_readonly        # 打印某条策略文档
  python3 rustfs_policy.py add iam_readonly policy.json   # 新增/覆盖（body = 策略 JSON）
  python3 rustfs_policy.py remove iam_readonly      # 删除

连接参数（默认值即 compose 里的 rustfsadmin/rustfsadmin，可用环境变量覆盖）：
  RUSTFS_ENDPOINT=http://127.0.0.1:9010
  RUSTFS_ACCESS_KEY / RUSTFS_SECRET_KEY
  RUSTFS_REGION=us-east-1

背景（与 ark-iam 的对接约定，详见 docker-compose.yml 顶部注释）：
  OIDC 用户的策略名 = CLAIM_PREFIX(`iam_`) + ID token `groups` 声明里的角色编码，纯拼接、无映射表；
  且未设置 ROLE_POLICY，故 groups 是唯一来源。策略缺失会被静默跳过，一个都没命中即拒绝登录。
  因此「ark-iam 应用角色模板里声明的每个 code」都必须在这里有一条同名 `iam_<code>` 策略。
"""
from __future__ import annotations

import datetime
import hashlib
import hmac
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ENDPOINT = os.environ.get("RUSTFS_ENDPOINT", "http://127.0.0.1:9010").rstrip("/")
ACCESS_KEY = os.environ.get("RUSTFS_ACCESS_KEY", "rustfsadmin")
SECRET_KEY = os.environ.get("RUSTFS_SECRET_KEY", "rustfsadmin")
REGION = os.environ.get("RUSTFS_REGION", "us-east-1")
SERVICE = "s3"

# RustFS 自带 admin 前缀优先，404 时退回 MinIO 兼容前缀
PREFIXES = ("/rustfs/admin/v3", "/minio/admin/v3")


def _hmac(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()


def _signing_key(date: str) -> bytes:
    key = _hmac(("AWS4" + SECRET_KEY).encode(), date)
    key = _hmac(key, REGION)
    key = _hmac(key, SERVICE)
    return _hmac(key, "aws4_request")


def _request(method: str, path: str, query: dict, body: bytes, content_type: str):
    host = urllib.parse.urlparse(ENDPOINT).netloc
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date, date = now.strftime("%Y%m%dT%H%M%SZ"), now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(body).hexdigest()

    canonical_query = "&".join(
        f"{urllib.parse.quote(k, safe='-_.~')}={urllib.parse.quote(v, safe='-_.~')}"
        for k, v in sorted(query.items())
    )
    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join(
        [method, path, canonical_query, canonical_headers, signed_headers, payload_hash]
    )
    scope = f"{date}/{REGION}/{SERVICE}/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode()).hexdigest(),
        ]
    )
    signature = hmac.new(_signing_key(date), string_to_sign.encode(), hashlib.sha256).hexdigest()

    url = f"{ENDPOINT}{path}" + (f"?{canonical_query}" if canonical_query else "")
    req = urllib.request.Request(url, data=body or None, method=method)
    req.add_header("Host", host)
    req.add_header("x-amz-date", amz_date)
    req.add_header("x-amz-content-sha256", payload_hash)
    req.add_header(
        "Authorization",
        f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY}/{scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}",
    )
    if body:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def call(method: str, suffix: str, query: dict | None = None, body: bytes = b"",
         content_type: str = "application/octet-stream"):
    result = None
    for prefix in PREFIXES:
        result = _request(method, prefix + suffix, query or {}, body, content_type)
        if result[0] != 404:
            return prefix, result[0], result[1]
    return (PREFIXES[-1], *result)


def _fetch_all() -> dict:
    _, status, data = call("GET", "/list-canned-policies")
    if status != 200:
        raise SystemExit(f"list-canned-policies 失败：http={status} {data[:300].decode('utf-8', 'replace')}")
    return json.loads(data)


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "list"

    if cmd == "list":
        policies = _fetch_all()
        for name in sorted(policies):
            actions = [a for st in policies[name].get("Statement", []) for a in st.get("Action", [])]
            mark = "  " if not name.startswith("iam_") else "→ "
            print(f"{mark}{name:<24} {', '.join(actions)}")
        print(f"\n共 {len(policies)} 条；`→` 为 ark-iam 契约命名空间（claim_prefix=iam_）")
        return 0

    if cmd == "show":
        policies = _fetch_all()
        name = argv[2]
        if name not in policies:
            raise SystemExit(f"策略不存在：{name}")
        print(json.dumps(policies[name], ensure_ascii=False, indent=2))
        return 0

    if cmd == "add":
        name, path = argv[2], argv[3]
        raw = open(path, "rb").read()
        json.loads(raw)  # 本地先校验，避免把坏 JSON 写进存储
        prefix, status, data = call("PUT", "/add-canned-policy", {"name": name}, raw, "application/json")
        print(f"add {name}: prefix={prefix} http={status} {data[:200].decode('utf-8', 'replace')}")
        return 0 if status == 200 else 1

    if cmd == "remove":
        name = argv[2]
        prefix, status, data = call("DELETE", "/remove-canned-policy", {"name": name})
        print(f"remove {name}: prefix={prefix} http={status} {data[:200].decode('utf-8', 'replace')}")
        return 0 if status == 200 else 1

    raise SystemExit(f"未知命令 {cmd}（可用：list / show / add / remove）")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
