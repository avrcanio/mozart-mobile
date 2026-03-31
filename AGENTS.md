# Repository Agent Notes

## Review Policy

- Do not use Kluster review tools in this repository.
- Do not run `kluster_code_review_auto`, `kluster_code_review_manual`, or `kluster_dependency_check`.
- Use local verification such as targeted tests, static analysis, and code review instead.

## GitHub Access

- GitHub CLI credentials are available in `C:\Users\avrca\Documents\Projects\hosts.yml`.
- Do not copy the token into this repository or print it in responses.
- For `gh` commands, use the config file by setting:

```powershell
$env:GH_CONFIG_DIR = 'C:\Users\avrca\Documents\Projects'
```

- For direct GitHub API calls, read the token from that `hosts.yml` file and pass it through an authorization header at runtime only.
- Prefer existing `gh` authentication over creating new credentials.
