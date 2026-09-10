#!/usr/bin/env python3
"""把构建产物同步发布到 Gitee 发行版，得到国内可直连的下载地址。

为什么不用现成的 action：Gitee 的「同名附件会累积而非覆盖」——
反复发同一版本会堆出一串同名文件，下载链接指向哪个并不确定。
这里上传前先删掉同名附件，保证直链永远指向最新产物。

依赖：仅标准库。环境变量 GITEE_TOKEN 提供私人令牌。

用法：
    GITEE_TOKEN=xxx python3 sync_gitee_release.py \
        --owner youzhai22 --repo shujing --tag v0.1.0 \
        --file shujing-v0.1.0.apk --title "书径 v0.1.0" \
        --notes-file RELEASE_NOTES.md
"""

import argparse
import json
import mimetypes
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://gitee.com/api/v5"


def request(method, path, token, fields=None, upload=None, timeout=1800):
    """调用 Gitee OpenAPI。

    access_token 一律走 query string（Gitee 对 GET/POST 都接受），
    其余参数走表单体：普通字段用 urlencoded，带文件时用 multipart。
    出错时抛 RuntimeError，附上服务端返回的原文，方便定位。
    """
    url = f"{API}{path}"
    sep = "&" if "?" in url else "?"
    url = f"{url}{sep}access_token={urllib.parse.quote(token)}"

    data = None
    headers = {"Accept": "application/json"}

    if upload:
        boundary = "----shujing" + secrets.token_hex(8)
        chunks = []
        for key, value in (fields or {}).items():
            chunks.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
            )
        for key, (filename, content) in upload.items():
            ctype = mimetypes.guess_type(filename)[0] or "application/octet-stream"
            chunks.append(
                (
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"; '
                    f'filename="{filename}"\r\nContent-Type: {ctype}\r\n\r\n'
                ).encode()
            )
            chunks.append(content)
            chunks.append(b"\r\n")
        chunks.append(f"--{boundary}--\r\n".encode())
        data = b"".join(chunks)
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    elif fields:
        data = urllib.parse.urlencode(fields).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"{method} {path} -> HTTP {exc.code}: {body[:500]}") from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{method} {path} -> 网络失败: {exc.reason}") from None

    if not raw.strip():
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def as_dict(payload):
    """Gitee 有些接口按 tag 查询时返回数组，统一成单个 dict。"""
    if isinstance(payload, list):
        return payload[0] if payload else {}
    return payload or {}


def ensure_tag(token, owner, repo, tag, ref):
    tags = request("GET", f"/repos/{owner}/{repo}/tags?per_page=100", token) or []
    names = [t.get("name") for t in tags if isinstance(t, dict)]
    if tag in names:
        print(f"[tag] {tag} 已存在")
        return
    request(
        "POST",
        f"/repos/{owner}/{repo}/tags",
        token,
        fields={"tag_name": tag, "refs": ref, "message": f"release {tag}"},
    )
    print(f"[tag] 已创建 {tag} -> {ref}")


def ensure_release(token, owner, repo, tag, title, notes, ref):
    existing = as_dict(request("GET", f"/repos/{owner}/{repo}/releases/tags/{tag}", token))
    if existing.get("id"):
        # 已存在则刷新标题与说明，避免旧文案残留
        request(
            "PATCH",
            f"/repos/{owner}/{repo}/releases/{existing['id']}",
            token,
            fields={"tag_name": tag, "name": title, "body": notes},
        )
        print(f"[release] 复用 id={existing['id']}")
        return existing["id"]

    created = as_dict(
        request(
            "POST",
            f"/repos/{owner}/{repo}/releases",
            token,
            fields={
                "tag_name": tag,
                "name": title,
                "body": notes,
                "target_commitish": ref,
                "prerelease": "false",
            },
        )
    )
    if not created.get("id"):
        raise RuntimeError(f"创建发行版失败: {created}")
    print(f"[release] 已创建 id={created['id']}")
    return created["id"]


def remove_same_name_assets(token, owner, repo, release_id, filename):
    """删掉同名附件——Gitee 不会自动覆盖，不删就会累积。"""
    assets = request("GET", f"/repos/{owner}/{repo}/releases/{release_id}/attach_files", token) or []
    removed = 0
    for asset in assets:
        if isinstance(asset, dict) and asset.get("name") == filename:
            request(
                "DELETE",
                f"/repos/{owner}/{repo}/releases/{release_id}/attach_files/{asset['id']}",
                token,
            )
            removed += 1
    if removed:
        print(f"[clean] 删除同名旧附件 {removed} 个")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--file", required=True, help="待上传的产物路径")
    parser.add_argument("--title", required=True)
    parser.add_argument("--notes", default="")
    parser.add_argument("--notes-file", default="")
    parser.add_argument("--ref", default="master", help="创建 tag 所指向的分支")
    parser.add_argument("--retries", type=int, default=3, help="上传失败重试次数")
    args = parser.parse_args()

    token = os.environ.get("GITEE_TOKEN", "").strip()
    if not token:
        sys.exit("缺少环境变量 GITEE_TOKEN")

    if not os.path.isfile(args.file):
        sys.exit(f"产物不存在: {args.file}")

    notes = args.notes
    if args.notes_file and os.path.isfile(args.notes_file):
        with open(args.notes_file, "r", encoding="utf-8") as handle:
            notes = handle.read()

    filename = os.path.basename(args.file)
    size_mb = os.path.getsize(args.file) / 1024 / 1024

    ensure_tag(token, args.owner, args.repo, args.tag, args.ref)
    release_id = ensure_release(token, args.owner, args.repo, args.tag, args.title, notes, args.ref)

    print(f"[upload] {filename} ({size_mb:.1f} MB)")
    with open(args.file, "rb") as handle:
        payload = handle.read()

    # 境外 runner 上传到 Gitee 可能很慢，单次写超时或中途断链都属常见，
    # 因此重试若干次；每次重试前都清一遍同名附件，避免残留半截文件。
    uploaded = None
    last_error = None
    for attempt in range(1, args.retries + 1):
        remove_same_name_assets(token, args.owner, args.repo, release_id, filename)
        started = time.time()
        try:
            uploaded = as_dict(
                request(
                    "POST",
                    f"/repos/{args.owner}/{args.repo}/releases/{release_id}/attach_files",
                    token,
                    upload={"file": (filename, payload)},
                )
            )
            elapsed = time.time() - started
            print(f"[upload] 第 {attempt} 次成功，耗时 {elapsed:.0f}s（{size_mb / max(elapsed, 0.1):.0f} KB/s 量级）")
            break
        except RuntimeError as exc:
            last_error = exc
            print(f"[warn] 第 {attempt} 次上传失败：{exc}")
            if attempt < args.retries:
                time.sleep(10 * attempt)

    if uploaded is None:
        sys.exit(f"上传失败，已重试 {args.retries} 次：{last_error}")

    url = uploaded.get("browser_download_url") or (
        f"https://gitee.com/{args.owner}/{args.repo}/releases/download/{args.tag}/{filename}"
    )
    print(f"[done] 下载地址: {url}")


if __name__ == "__main__":
    main()
