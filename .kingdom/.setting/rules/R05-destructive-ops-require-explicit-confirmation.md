### R5. Destructive ops require explicit confirmation

`rm -rf`, `git reset --hard`, `git branch -D`, `git stash drop`, `git worktree remove --force`, schema migrations, dropping a database table, killing a long-running process — all require explicit confirmation that includes the **specific target**. "Yes go ahead" is not enough; the response must reference what's being destroyed.
