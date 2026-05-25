Run the Dark Flow installer — works for fresh projects and existing ones alike:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
```

Options:
- `--all` — enable all optional modules non-interactively
- `-y / --yes` — accept defaults with no prompts
- `--dry-run` — preview changes without applying
- `--force` — re-apply all templates, skip version check
