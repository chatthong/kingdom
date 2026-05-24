### R4. Never edit or commit on `kingdom` branch

Kingdom is the working-tree overlay (v0.17.0+). Pattern: `git reset --hard origin/develop` → overlay lanes via `git apply` → review → `git restore .`. NO commits on kingdom. NO `git merge --no-ff worker-N` on kingdom.
