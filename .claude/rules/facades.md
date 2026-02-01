---
globs: ["lib/src/facades/**"]
---

# Facade Conventions

- Static classes providing context-free access to services
- Two resolution strategies: static singleton (`_instance`) or container (`Magic.make<T>()`)
- Never instantiate facades — all methods are static
- Each facade proxies to a manager or service class
- Keep facades thin — delegate logic to underlying service
