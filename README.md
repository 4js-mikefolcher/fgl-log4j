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

## Dependency on the Genero GRE's bundled Log4j ⚠️

> **This is the most important compatibility note for this package.**

The Genero Runtime Environment (GRE) — the JVM bridge `fglrun` uses for
`IMPORT JAVA` — **ships its own Log4j 2** in its jar directory:

```
$FGLDIR/../gre/lib/jars/log4j-api-2.17.1.jar
$FGLDIR/../gre/lib/jars/log4j-core-2.17.1.jar
```

(Verified on Genero 6.00.03; path is `gre/lib/jars` relative to the
Genero install root.)

Important nuance — **those jars are for the GRE's *own* internal logging
and are not placed on your application's `CLASSPATH`.** Application code
that does `IMPORT JAVA org.apache.logging.log4j.*` must supply Log4j on
the `CLASSPATH` itself; with the GRE jars absent you get
`java.lang.NoClassDefFoundError: org/apache/logging/log4j/Level` at the
first call. That is why `fglpkg.json` declares **both** `log4j-api` and
`log4j-core` as `java` dependencies — `fglpkg install` downloads them
into `.fglpkg/jars`, and the `Makefile` puts that directory on the
`CLASSPATH` for both `fglcomp` and `fglrun`.

Consequences you must respect:

1. **Pin to the GRE's version (2.17.1).** Even though the GRE's copy
   isn't on your app classpath, your app's JVM is the GRE's JVM. Matching
   the GRE's bundled version (2.17.1) avoids any chance of two different
   Log4j versions being loaded into the same VM, and avoids
   `NoSuchMethodError` / `LinkageError` from `log4j-api`/`log4j-core`
   skew. **Do not bump one of the two without the other.**

2. **Co-existence with other packages.** Packages such as
   [`poiapi`](https://github.com/4js-mikefolcher/poiapi) also depend on
   `log4j-api 2.17.1` for the same reason. Pinning here keeps a single,
   consistent Log4j version across an application's dependency set.

3. **Both `log4j-api` and `log4j-core` are required at runtime.**
   `log4j-api` is the facade; `log4j-core` is the implementation that
   actually emits log records and that this package reconfigures for
   `setLevel`/`setRootLevel`. Neither is optional.

If you upgrade Genero and the bundled Log4j version changes, update the
two `version` fields in `fglpkg.json` to match — and re-run
`fglpkg install`.

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
fglpkg install            # fetches log4j-api / log4j-core 2.17.1 into .fglpkg/jars
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
