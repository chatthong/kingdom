### R12. Every per-task artifact carries the lane in segment 2 (v0.15.2+)

`tasks/<UTC>__<lane>__<id>.md`, `logs/<UTC>__<lane>__<id>.md`, `logs/raw/<UTC>__<sub>-<lane>__<id>.md`, `logs/done/<UTC>__<sub>-<lane>__<id>.flag`, `docs/test-reports/KING_<UTC>__<lane>__<id>.md`. Grep contract: `ls *__worker-3__*` returns lane's full history.
