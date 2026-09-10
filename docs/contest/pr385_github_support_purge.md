# PR #385 public-history purge (owner ops)

**Not** a judging file. **Never** paste old non-reserved E.164, `CALLE_API_KEY`, or App Passwords here.

Contest Must URL: [CALLE-AI/awesome-phone-call-agents#385](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/385).  
Keep mergeable head **`9b12a7ca049ad6d4a8d267fe22e8c4c7d27d0d8a`**. Do not amend, force-push, close the PR, or delete the fork.

## GitHub Support ticket (filed)

| Field | Value |
| --- | --- |
| Ticket | **#4744420** (Repositories) |
| Account | `@akrmcodes` |
| From | `akrm.codes@gmail.com` |
| Subject | Purge cached commits / run garbage collection for sensitive data |
| Status | open (created 2026-09-10) |
| Portal | [GitHub Support](https://support.github.com/tickets) |

Ask was: GC + cached-view removal of unreachable SHAs after force-push; **preserve open PR #385**; no LFS.

GitHub’s documented default for affected PRs is dereference **or delete**. Preserve #385 is case-by-case. If Support replies that they must close/delete the PR, stop and re-read before agreeing.

Dropped reviewed heads (still HTTP **200** until Support GC — expected):

- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/5f776982829f0c1371fef347fa2dd2131cea452d
- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/c1396c9ee4443d46362b7db023646ffbeb6db4ea
- https://github.com/CALLE-AI/awesome-phone-call-agents/commit/da77bce13131f1401b57f42263291b8e9403156b

Same SHAs on `akrmcodes/awesome-phone-call-agents`. Keep-head `9b12a7c` must stay **200**.

Docs: [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

## Paste on PR #385 (owner)

Cursor is not posting this. Paste as a new conversation comment. Do **not** quote prior comments that contained full non-reserved E.164.

```
@Ray-56 Public-history purge requested.

Mergeable head remains 9b12a7ca049ad6d4a8d267fe22e8c4c7d27d0d8a (one commit on current main). No further skill rewrite.

GitHub Support ticket #4744420 asks for garbage collection and removal of cached commit views for these unreachable reviewed heads (force-pushed off the branch; still HTTP 200):

https://github.com/CALLE-AI/awesome-phone-call-agents/commit/5f776982829f0c1371fef347fa2dd2131cea452d
https://github.com/CALLE-AI/awesome-phone-call-agents/commit/c1396c9ee4443d46362b7db023646ffbeb6db4ea
https://github.com/CALLE-AI/awesome-phone-call-agents/commit/da77bce13131f1401b57f42263291b8e9403156b

Same SHAs on akrmcodes/awesome-phone-call-agents. Please keep this PR open. We will comment again when those URLs return 404.
```

## After Support GC

Do **not** claim merge until the dropped URLs return **404** on both repos, then a short follow-up on #385.

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

Expect **404** on the three dropped SHAs and **200** on `9b12a7c`. Until then, SHA pages staying 200 is expected. No further skill commit can fix this.

Roadmap §6.4 / §6.3 stay open until Ray (or confirmed 404) — do not tick merge.
