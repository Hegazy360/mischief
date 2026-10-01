# Allowed skips in the suite (pre-gate row 2)

`tools/scripts/pregate3d.sh` row 2 reads the first column of this table: every `skip <test id> — <reason>` line the
suite prints must be listed here with its reason and the R3 task that removes it, or row 2 fails.

| test id | reason | R3 task that removes it |
|---|---|---|

On `r3d` at the pre-gate run the suite prints **no skip** (1262+ passed, 0 skipped), so the table is empty. A skip that
appears later must be added here (with its reason and owner) before the pre-gate can pass.
