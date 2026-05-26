# Changelog

## 2026-03-15
- v1.2.0: Fix fivem-appearance ESX skin model extraction — was querying non-existent `model` column from `users` table, now correctly extracts model from skin JSON data

## 2026-02-13
- v9: Extract model from skin JSON for illenium-appearance ESX (leaderboard peds display correct model)
- v8: Separated ESX (users.skin) from QB (playerskins) for illenium-appearance skin loading
- v7: Dynamic column detection for playerskins table (citizenid/identifier/id) via INFORMATION_SCHEMA
- v6: Multiple death detection methods (CEventNetworkEntityDamage + IsEntityDead, QB metadata watcher)
