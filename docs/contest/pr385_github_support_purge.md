# PR #385 public-history purge (owner ops)

**Not** a judging file. **Never** paste old non-reserved E.164, `CALLE_API_KEY`, or App Passwords here.

Contest Must URL: [CALLE-AI/awesome-phone-call-agents#385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385) — **merged** 2026-09-11 by Ray-56 (head `9b12a7c`, merge `31808d8`). Do not open a second skill PR. Do not amend or force-push the skill clone.

Ray-56 superseding review (community policy 2026-09-11): the blanket synthetic-fixture / history-cache purge is **withdrawn**. No remaining Must Fix. Dropped SHA pages may still return HTTP 200; that is **not** a contest merge blocker.

## GitHub Support ticket (filed)

| Field | Value |
| --- | --- |
| Ticket | **#4744420** (Repositories) |
| Account | `@akrmcodes` |
| From | `akrm.codes@gmail.com` |
| Subject | Purge cached commits / run garbage collection for sensitive data |
| Status | still Open in Support UI as of 2026-09-11; **close, do not delete** (see below) |
| Portal | [GitHub Support](https://support.github.com/tickets) |

Ask was: GC + cached-view removal of unreachable SHAs after force-push; **preserve PR #385**; no LFS. The PR is now merged; do not ask Support to unwind it.

Dropped reviewed heads (may still be HTTP **200** until Support GC — optional hygiene, not a merge blocker):

- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/5f776982829f0c1371fef347fa2dd2131cea452d
- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/c1396c9ee4443d46362b7db023646ffbeb6db4ea
- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/da77bce13131f1401b57f42263291b8e9403156b

Same SHAs on `akrmcodes/awesome-phone-call-agents`. Keep-head `9b12a7c` must stay **200**.

Docs: [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

## Historical: paste on PR #385 (already posted)

Owner already posted the Ray comment before merge. Do not paste it again.

```
@Ray-56 Public-history purge requested.

Mergeable head remains 9b12a7ca049ad6d4a8d267fe22e8c4c7d27d0d8a (one commit on current main). No further skill rewrite.

GitHub Support ticket #4744420 asks for garbage collection and removal of cached commit views for these unreachable reviewed heads (force-pushed off the branch; still HTTP 200):

https://github.com/CALLE-AI/awesome-phone-call-agents/commit/5f776982829f0c1371fef347fa2dd2131cea452d
https://github.com/CALLE-AI/awesome-phone-call-agents/commit/c1396c9ee4443d46362b7db023646ffbeb6db4ea
https://github.com/CALLE-AI/awesome-phone-call-agents/commit/da77bce13131f1401b57f42263291b8e9403156b

Same SHAs on akrmcodes/awesome-phone-call-agents. Please keep this PR open. We will comment again when those URLs return 404.
```

## Close the Support ticket (do not delete)

GitHub Support tickets are **closed**, not deleted. Closing is the right move now that #385 is merged and purge is no longer a Must Fix.

Optional one-line comment, then **Close ticket**:

```
PR CALLE-AI/awesome-phone-call-agents#385 was merged 2026-09-11. Maintainer withdrew the history-cache purge as a merge blocker. Remaining SHA pages (if still 200) are optional hygiene, not a contest issue. Please close this ticket.
```

If Support still GCs the three dropped SHAs, that is welcome hygiene. Do not reopen a merge fight.

## After Support GC (optional hygiene)

SHA pages staying 200 is expected until GitHub GCs. No further skill commit can fix this. Merge of #385 does **not** depend on 404.

```bash
for repo in akrmcodes/awesome-phone-call-agents CALLE-AI/awesome-phone-call-agents; do
  for sha in \
    5f776982829f0c1371fef347fa2dd2131cea452d \
    c1396c9ee4443d46362b7db023646ffbeb6db4ea \
    da77bce13131f1401b57f42263291b8e9403156b \
    9b12a7ca049ad6d4a8d267fe22e8c4c7d27d0d8a; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' "https://github.com/${repo}/commit/${sha}")
    echo "$code $repo $sha"
  done
done
```

Expect **404** on the three dropped SHAs and **200** on `9b12a7c` only if Support GCs. Until then, SHA pages staying 200 is expected.

Roadmap §6.4 review/validate boxes are done. Leave Devpost URL paste and §6.3 video open.
