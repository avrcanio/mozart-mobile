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

## GitHub Writing Style

- Apply these rules to all GitHub issue comments, issue bodies, PR comments, PR bodies, and milestone/project notes written for this repository.
- Always write GitHub text as clean Markdown, not as escaped plain text.
- Never post literal escape sequences such as `\n`, `\t`, or malformed control characters.
- Use short sections when helpful, for example `**Delivered**`, `**Changed**`, `**Verification**`, `**Follow-up**`.
- Keep lists flat. Use `-` bullets only. Do not use nested bullets.
- Wrap code, commands, identifiers, routes, and labels in backticks.
- When listing verification, prefer a short bullet list of actual commands that were run.
- Keep tone direct and professional. Do not add filler, hype, or vague status text.
- State the concrete outcome first, then the important details.
- If an issue was implemented, the default comment structure should be:

```md
Implemented <short description>.

**Delivered**
- <change 1>
- <change 2>

**Verification**
- <command 1>
- <command 2>
```

- If an issue was reviewed but not fully implemented, clearly separate:
  - what was confirmed
  - what remains open
  - what the next step is
- Before posting any GitHub comment, quickly verify that the rendered text will be readable:
  - no escaped newlines
  - no broken Unicode/control characters
  - no accidental one-line paragraph dumps
