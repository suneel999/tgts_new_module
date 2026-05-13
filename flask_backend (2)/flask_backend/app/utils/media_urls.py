"""Resolve stored media paths to absolute URLs for API clients."""

from __future__ import annotations

from flask import current_app


def absolute_media_url(url: str | None) -> str | None:
    """
    Turn relative paths like /uploads/... into full URLs using PUBLIC_BASE_URL.

    Already-absolute URLs (http/https), including S3 URLs, are returned unchanged.
    If PUBLIC_BASE_URL is unset, relative URLs are returned as-is (legacy behaviour).
    """
    if url is None:
        return None
    if not isinstance(url, str):
        return url
    u = url.strip()
    if not u:
        return u
    if u.startswith(("http://", "https://")):
        return u
    base = (current_app.config.get("PUBLIC_BASE_URL") or "").strip().rstrip("/")
    if not base:
        return url
    if u.startswith("/"):
        return f"{base}{u}"
    return f"{base}/{u}"
