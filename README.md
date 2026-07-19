# fgl-log4j

A Genero BDL logging facade over [Apache Log4j 2](https://logging.apache.org/log4j/2.x/)
(`org.apache.logging.log4j`). Application code logs through plain BDL
functions and never touches Java; Log4j does the work underneath.

## Why a facade

The Java `Logger` object is kept private to the wrapper module. Callers
refer to loggers by **name** (a `STRING`) and pass **pre-formatted
messages** (use `SFMT` for substitution). This keeps the public API pure
BDL — consuming modules do **not** need `IMPORT JAVA` — and side-steps
Java method-overload and varargs resolution in client code.

```4gl
IMPORT FGL com.fourjs.log4j.Log4j AS log

MAIN
    DEFINE args DYNAMIC ARRAY OF STRING

    -- Pre-formatted message (SFMT on the BDL side):
    CALL log.info("com.acme.orders", "Order accepted")
    CALL log.error("com.acme.orders", SFMT("Order %1 rejected: %2", id, reason))

    -- Or let Log4j substitute "{}" placeholders (deferred until the level
    -- is enabled), passing arguments as a DYNAMIC ARRAY OF STRING:
    LET args[1] = id
    LET args[2] = reason
    CALL log.errorp("com.acme.orders", "Order {} rejected: {}", args)

    CALL log.shutdown()   -- flush appenders before exit
END MAIN
```

## Coexistence with the Genero Report Engine's Log4j ⚠️

> **This is the most important compatibility note for this package.**

The Genero Report Engine's `gre.jar` uses Log4j 2 internally. It contains
**no log4j classes itself** — it pulls them in through its
`META-INF/MANIFEST.MF` `Class-Path`, which references its own bundled copy
next to it:

```
$GREDIR/lib/jars/log4j-api-2.17.1.jar
$GREDIR/lib/jars/log4j-core-2.17.1.jar
```

(Verified on Genero 6.00.03; `$GREDIR` is the `gre` directory of the
Genero install.)

Because those jars enter a JVM only via `gre.jar`'s manifest, they are
**not** on a plain application's `CLASSPATH`. Application code that does
`IMPORT JAVA org.apache.logging.log4j.*` must supply Log4j itself; with no
log4j present you get `java.lang.NoClassDefFoundError:
org/apache/logging/log4j/Level` at the first call. That is why
`fglpkg.json` declares **both** `log4j-api` and `log4j-core` as `java`
dependencies — `fglpkg install` downloads them into `.fglpkg/jars`, and
the `Makefile` puts that directory on the `CLASSPATH` for both `fglcomp`
and `fglrun`.

This package ships the **latest Log4j 2.x** (currently **2.26.1**), not
the Report Engine's older 2.17.1 — 2.17.1 carries three known CVEs
(fixed in 2.25.3 / 2.25.4) that block publication.

Rules you must respect:

1. **Keep `log4j-api` and `log4j-core` in lock-step.** The one real
   hazard is a *version skew* between the two (e.g. api 2.26.1 + core
   2.17.1 in one VM → `NoSuchMethodError` / `AbstractMethodError`). Always
   bump both together. Matching the Report Engine's exact version is **not**
   required.

2. **When the Report Engine runs in-process, your log4j must come *first*
   on the `CLASSPATH`.** If the same `fglrun` program both logs through
   this package *and* drives the Report Engine in the same JVM, `gre.jar`
   is on the classpath and its manifest offers 2.17.1. A single classloader
   exposes only one version of each class, and the **first** copy on the
   `CLASSPATH` wins for the whole VM. Put `.fglpkg/jars` (both jars) ahead
   of `gre.jar` so 2.26.1 wins. The Report Engine's own code (built for
   2.17.1) then runs on 2.26.1 — the backward-compatible direction, which
   is verified working (see below). The `Makefile` already prepends
   `.fglpkg/jars`; a consuming app / GAS deployment must ensure the same
   ordering.

3. **Security note — declaring a version is not the same as running it.**
   If you declare 2.26.1 but let `gre.jar` sit *ahead* of your jars, the
   older 2.17.1 silently wins at runtime while the audit (which scans the
   declared version) shows green. Ordering is a correctness *and* a
   security requirement. Call **`getLog4jInfo()`** at startup to confirm
   the version actually loaded — it returns e.g.
   `2.26.1 @ file:.../log4j-core-2.26.1.jar`.

4. **Both `log4j-api` and `log4j-core` are required at runtime.**
   `log4j-api` is the facade; `log4j-core` emits the log records and is
   what this package reconfigures for `setLevel`/`setRootLevel`. Neither
   is optional.

**Verified (Genero 6.00.01 GRE, Java arm64):** with 2.26.1 ahead of
`gre.jar`, `getLog4jInfo()` reports 2.26.1, logging works with
`getLastError()` NULL (no skew), and the Report Engine
(`com.fourjs.report.main.GReportWriter`) loads log4j-api **and**
log4j-core 2.26.1 and emits records through it with no `LinkageError`.
The Report Engine runs fine on 2.26.1.

## Runtime level changes: why not `Configurator`?

Log4j's documented helper for programmatic level changes,
`org.apache.logging.log4j.core.config.Configurator.setLevel(...)`,
**does not work under the Genero Java bridge**: it internally resolves
the `LoggerContext` via `LoggerContext.getContext(false)`, which infers
the context from the *immediate caller's* classloader. Called from
inside `log4j-core`, that does not resolve to the context our loggers
live in, so the level change is silently applied to the wrong context
and has no effect (no error is raised).

`setLevel`/`setRootLevel` in this package therefore resolve the context
from *this module's* caller (`LogManager.getContext(false)` called from
BDL), edit the running `Configuration`'s `LoggerConfig` directly, and
call `updateLoggers()`. This takes effect immediately and is verified by
the demo (`setLevel(name,"WARN")` suppresses subsequent `INFO`).

## Installation

```bash
fglpkg install            # fetches log4j-api / log4j-core 2.26.1 into .fglpkg/jars
```

Add the package to a consuming project's `fglpkg.json` dependencies, or
build locally with the included `Makefile`.

## Configuration

Log4j 2 auto-discovers a `log4j2.xml` (or `.properties`/`.json`) on the
`CLASSPATH`. A sample console configuration is provided in
[bin/log4j2.xml](bin/log4j2.xml). Levels can also be changed at runtime
through `setLevel` / `setRootLevel` (which edit the running
`Configuration` directly — see "why not `Configurator`?" above).

## Public API

All functions live in module `com.fourjs.log4j.Log4j`.

| Function | Description |
|----------|-------------|
| `getLogger(name STRING) RETURNS STRING` | Validate/register a logger; returns the name as a handle. |
| `getRootLogger() RETURNS STRING` | The root-logger handle (a `NULL` name). |
| `trace(name, message)` | Log at TRACE. |
| `debug(name, message)` | Log at DEBUG. |
| `info(name, message)` | Log at INFO. |
| `warn(name, message)` | Log at WARN. |
| `error(name, message)` | Log at ERROR. |
| `fatal(name, message)` | Log at FATAL. |
| `log(name, levelName, message)` | Log at a level chosen by name at runtime. |
| `tracep/debugp/infop/warnp/errorp/fatalp(name, message, args)` | Parameterized: `{}` placeholders in `message` are filled from `args` (a `DYNAMIC ARRAY OF STRING`). |
| `logp(name, levelName, message, args)` | Parameterized `log()`. |
| `isEnabled(name, levelName) RETURNS BOOLEAN` | Is the logger enabled for this level? |
| `setLevel(name, levelName)` | Set a named logger's level (edits the running `Configuration`; takes effect immediately). |
| `setRootLevel(levelName)` | Set the root logger's level (edits the running `Configuration`; takes effect immediately). |
| `shutdown()` | Flush and stop Log4j; call before program exit. |
| `getLastError() RETURNS STRING` | Message from the most recent failed call (`NULL` if none). |
| `getLog4jInfo() RETURNS STRING` | Diagnostic: the log4j-core version and JAR actually loaded (`"<version> @ <jar-url>"`). Use it to confirm the shipped version won the classloader when the Report Engine runs in-process. |

A `name` of `NULL` or `""` targets the **root logger**. Level names are
case-insensitive: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`
(also `OFF`, `ALL`).

Logging calls never throw: any underlying Java failure is swallowed and
recorded in `getLastError()`, so a logging problem can never crash the
host application.

### Parameterized (`{}`) logging

The `p` variants accept Log4j `{}` placeholders and a
`DYNAMIC ARRAY OF STRING` of arguments, substituted in order:

- More placeholders than args → the extra `{}` are left literal
  (`"{} of {} done"` with `["5"]` → `5 of {} done`).
- More args than placeholders → the extras are ignored.
- An empty args array behaves exactly like the plain variant.
- **Empty-string nuance:** Genero treats an empty `STRING` as `NULL`,
  and Log4j renders a null argument as the text `"null"`. So an `args`
  element of `""` appears as `null` in the output, not as an empty
  string.

The substitution (and the cost of building the final string) is deferred
until Log4j confirms the level is enabled — so a suppressed `debugp(...)`
does no formatting work.

## Building the demo

```bash
fglpkg install
make            # builds the lib module and the test driver
make run        # runs bin/log4j_test.42r with bin/log4j2.xml on the classpath
```

`JAVA_HOME` must be set for `fglcomp`/`fglrun` to start the JVM.

## Layout

```
fglpkg.json              package manifest (incl. java deps)
lib/Log4j.4gl            the facade module (PACKAGE com.fourjs.log4j)
src/log4j_test.4gl       test/demo driver
bin/log4j2.xml           sample Log4j 2 console configuration
Makefile                 build (lib + demo)
LICENSE                  Apache License 2.0
NOTICE                   attribution notice
```

## License

Licensed under the [Apache License 2.0](LICENSE) — the same license as
Apache Log4j. See [NOTICE](NOTICE) for attribution.
