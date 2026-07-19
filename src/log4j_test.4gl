IMPORT FGL com.fourjs.log4j.Log4j AS log

#+ Exercises the fgl-log4j facade: plain logging, level control, and the
#+ "{}" parameterized variants (including edge cases). Output goes to the
#+ console via bin/log4j2.xml on the CLASSPATH.
MAIN
    DEFINE name STRING
    DEFINE args DYNAMIC ARRAY OF STRING

    LET name = "com.fourjs.log4j.demo"

    DISPLAY "===== 0. loaded log4j-core (version @ jar) ====="
    DISPLAY log.getLog4jInfo()

    CALL log.setRootLevel("DEBUG")

    DISPLAY "===== 1. plain severity methods ====="
    CALL log.trace(name, "trace() - filtered out at DEBUG root level")
    CALL log.debug(name, "debug() - low-level diagnostic detail")
    CALL log.info(name, "info() - application started")
    CALL log.warn(name, "warn() - something looks off")
    CALL log.error(name, SFMT("error() - SFMT pre-formatted, %1 retries", 3))
    CALL log.fatal(name, "fatal() - unrecoverable")
    CALL log.log(name, "INFO", "log() - level chosen by name")

    DISPLAY "===== 2. parameterized {} variants ====="
    -- Exact number of args.
    CALL args.clear()
    LET args[1] = "3"
    LET args[2] = "Acme Corp"
    CALL log.infop(name, "processed {} orders for {}", args)   -- 3 orders for Acme Corp

    -- Fewer args than placeholders: leftover {} stays literal.
    CALL args.clear()
    LET args[1] = "5"
    CALL log.infop(name, "{} of {} steps done", args)          -- 5 of {} steps done

    -- More args than placeholders: extras ignored.
    CALL args.clear()
    LET args[1] = "first"
    LET args[2] = "ignored-extra"
    CALL log.infop(name, "only {} matters", args)              -- only first matters

    -- Empty args array: behaves like the plain variant.
    CALL args.clear()
    CALL log.infop(name, "no placeholders, no args", args)     -- verbatim

    -- A literal value that looks numeric, plus an empty string.
    -- NOTE: Genero treats an empty STRING as NULL, and Log4j renders a
    -- null argument as the text "null" -- so the second placeholder
    -- becomes note='null', not note=''.
    CALL args.clear()
    LET args[1] = "0042"
    LET args[2] = ""
    CALL log.warnp(name, "code={} note='{}'", args)            -- code=0042 note='null'

    -- Generic parameterized log by level name.
    CALL args.clear()
    LET args[1] = "DB-7"
    CALL log.logp(name, "ERROR", "subsystem {} failed", args)  -- subsystem DB-7 failed

    DISPLAY "===== 3. level checks and runtime level change ====="
    IF log.isEnabled(name, "TRACE") THEN
        CALL log.trace(name, "TRACE enabled")
    ELSE
        CALL log.info(name, "isEnabled(TRACE)=FALSE (expected at DEBUG)")
    END IF

    -- Raise this logger to WARN: subsequent INFO/DEBUG suppressed.
    CALL log.setLevel(name, "WARN")
    CALL log.info(name, "this INFO must be suppressed now")
    CALL args.clear()
    LET args[1] = "suppressed"
    CALL log.debugp(name, "this DEBUG ({}) must be suppressed", args)
    CALL log.warn(name, "this WARN still shows after setLevel(WARN)")
    CALL args.clear()
    LET args[1] = "shown"
    CALL log.warnp(name, "this WARN ({}) still shows", args)

    DISPLAY "===== 4. error-channel assertion ====="
    IF log.getLastError() IS NULL THEN
        DISPLAY "PASS: getLastError() is NULL - no swallowed Java errors"
    ELSE
        DISPLAY SFMT("FAIL: getLastError()=%1", log.getLastError())
    END IF

    CALL log.shutdown()
END MAIN
