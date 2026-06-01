#!/usr/bin/env python3
"""Fetch Codex rate limit quota from ChatGPT backend API.

Caches result for 5 minutes to avoid hammering the API on every statusline refresh.
Outputs JSON with keys: primary_pct, primary_reset_secs, secondary_pct, secondary_reset_secs
"""
import json, os, ssl, sys, time, urllib.request

CACHE_FILE = os.path.expanduser("~/.claude/.codex_quota_cache.json")
CACHE_TTL = 300  # 5 minutes
AUTH_FILE = os.path.expanduser("~/.codex/auth.json")
API_URL = "https://chatgpt.com/backend-api/codex/usage"


def load_cache():
    try:
        with open(CACHE_FILE) as f:
            data = json.load(f)
        if time.time() - data.get("_cached_at", 0) < CACHE_TTL:
            return data
    except Exception:
        pass
    return None


def fetch_quota():
    with open(AUTH_FILE) as f:
        auth = json.load(f)
    token = auth["tokens"]["access_token"]
    account_id = auth["tokens"]["account_id"]

    headers = {
        "Authorization": f"Bearer {token}",
        "ChatGPT-Account-Id": account_id,
        "OAI-Product-Sku": "codex",
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
    }
    ctx = ssl.create_default_context()
    req = urllib.request.Request(API_URL, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=8) as r:
        raw = json.loads(r.read())

    rl = raw.get("rate_limit", {})
    pw = rl.get("primary_window", {})
    sw = rl.get("secondary_window", {})

    result = {
        "_cached_at": time.time(),
        "primary_pct": pw.get("used_percent", 0),
        "primary_reset_secs": pw.get("reset_after_seconds", 0),
        "primary_reset_at": pw.get("reset_at", 0),
        "secondary_pct": sw.get("used_percent", 0),
        "secondary_reset_secs": sw.get("reset_after_seconds", 0),
        "secondary_reset_at": sw.get("reset_at", 0),
        "limit_reached": rl.get("limit_reached", False),
        "plan_type": raw.get("plan_type", "unknown"),
    }

    with open(CACHE_FILE, "w") as f:
        json.dump(result, f)
    return result


def main():
    data = load_cache()
    if data is None:
        try:
            data = fetch_quota()
        except Exception as e:
            print(json.dumps({"error": str(e)}))
            sys.exit(1)
    print(json.dumps(data))


if __name__ == "__main__":
    main()
