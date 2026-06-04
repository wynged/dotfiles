# Code Reuse

Before writing new logic, actively search for existing implementations in the codebase:

- **Search for callers, not just APIs.** Before using a low-level method, grep for who else calls it. Existing callers often reveal higher-level wrappers that handle boilerplate you'd otherwise reimplement.
- **Search by concept.** If you need "find elements near a box," search for terms like `findElements`, `elementsNear`, etc. Don't stop at the first low-level primitive you find.
- **Bridging code is a smell.** If you're writing 5+ lines translating between layers (e.g. raw query results to typed domain objects), that bridge likely already exists. Search before writing it.
- **Check neighboring code for patterns.** Before implementing a new function, read how similar functions nearby solve the same class of problem. They often use helpers you don't know about yet.
