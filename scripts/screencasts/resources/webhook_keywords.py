"""HTTP-only keyword for resetting demo content between webhook screencast
takes -- no raw Playwright page beyond the current session's own request
context, following the same pattern as
collective/collective.bpmproxy's scripts/screencasts/resources/bpmproxy_keywords.py
in the robotframework-screencast repository's legacy-playground branch.
"""

from screencast.library import _SESSION


def _page():
    page = _SESSION.current_page
    if page is None:
        raise AssertionError(
            "No open page -- call Start Observer or Start Actor Turn first"
        )
    return page


def delete_demo_content(paths, base_url):
    """Remove leftover top-level demo content before a take. `paths` is a
    Robot list of site-relative paths; 404 is fine on a first run."""
    for path in paths:
        response = _page().request.delete(
            f"{base_url}/{str(path).lstrip('/')}",
            headers={"Accept": "application/json"},
        )
        if response.status not in (200, 204, 404):
            raise AssertionError(
                f"Could not remove demo content {path!r}: "
                f"{response.status} {response.text()}"
            )
