# _primitives — moved (v0.34.0)

Helpers are now **one function per file** under [`functions/`](functions/). Start at the registry:

➡ **[`functions/index.md`](functions/index.md)** — every helper with its file.

Source the loader and pull only what a run calls:

```bash
source .kingdom/.setting/functions/_load.sh
load render_card spawn_master_workspace kingdom_overlay_lane
```
