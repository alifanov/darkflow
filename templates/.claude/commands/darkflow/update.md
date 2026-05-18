Run the Dark Flow updater — compares installed version against latest, shows changelog, and smart-updates template files (preserves local modifications unless --force is passed):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/update.sh)
```

Options:
- `--dry-run` — show what would change without applying anything
- `--force` — overwrite template files even if locally modified
