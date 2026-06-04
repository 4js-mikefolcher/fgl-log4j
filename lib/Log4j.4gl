PACKAGE com.fourjs.log4j

#+ Genero BDL logging facade over Apache Log4j 2.
#+
#+ This module wraps the org.apache.logging.log4j API so application code
#+ can log without ever touching Java. The Java Logger object is kept
#+ private to this module; callers refer to loggers by *name* (a plain
#+ STRING).
#+
#+ Two ways to build a message:
#+   - Plain functions (info/debug/...) take a pre-formatted STRING. Use
#+     SFMT for substitution on the BDL side.
#+   - The "p" variants (infop/debugp/...) take a message with Log4j "{}"
#+     placeholders plus a DYNAMIC ARRAY OF STRING of arguments. Log4j
#+     substitutes the arguments in order and -- crucially -- only builds
#+     the final string when the level is enabled, so disabled log calls
#+     stay cheap.
#+
#+ Log4j itself caches one Logger per name, so resolving a logger by name
#+ on every call is cheap -- no extra caching is done here.
#+
#+ Runtime configuration is driven by a log4j2.xml on the CLASSPATH, as
#+ usual for Log4j 2. Levels can also be changed programmatically with
#+ setLevel()/setRootLevel() -- see applyLevel() for why we edit the
#+ Configuration directly instead of using log4j-core's Configurator.
#+
#+ Requires log4j-api and log4j-core 2.17.1 on the CLASSPATH (fglpkg
#+ installs them). The GRE bundles its own copy for internal use only;
#+ see README.md.

IMPORT JAVA org.apache.logging.log4j.LogManager
IMPORT JAVA org.apache.logging.log4j.Logger
IMPORT JAVA org.apache.logging.log4j.Level
IMPORT JAVA org.apache.logging.log4j.core.LoggerContext
IMPORT JAVA org.apache.logging.log4j.core.config.Configuration
IMPORT JAVA org.apache.logging.log4j.core.config.LoggerConfig
IMPORT JAVA java.lang.Object

#+ Java Object[] used to pass "{}" substitution arguments to Log4j.
PRIVATE TYPE objArray ARRAY[] OF java.lang.Object

#+ Last error captured from a failed Log4j call. Logging must never crash
#+ the host application, so failures are swallowed and recorded here for
#+ diagnostics (see getLastError()).
PRIVATE DEFINE m_lastError STRING

#+ Resolve the underlying Log4j Logger for a name.
#+ A NULL or empty name resolves to the root logger.
PRIVATE FUNCTION resolveLogger(name STRING) RETURNS Logger
    IF name IS NULL OR name == "" THEN
        RETURN LogManager.getRootLogger()
    END IF
    RETURN LogManager.getLogger(name)
END FUNCTION

#+ Map a level name ("INFO", "debug", ...) to a Log4j Level object.
#+ Returns NULL for an unknown name (callers must guard).
PRIVATE FUNCTION resolveLevel(levelName STRING) RETURNS Level
    IF levelName IS NULL THEN
        RETURN NULL
    END IF
    RETURN Level.getLevel(levelName.toUpperCase())
END FUNCTION

#+ Ensure a named logger exists and return its name as an opaque handle.
#+ Useful to validate a name up front; logging functions accept the name
#+ directly and do not require a prior getLogger() call.
PUBLIC FUNCTION getLogger(name STRING) RETURNS STRING
    DEFINE lgr Logger
    LET lgr = resolveLogger(name)   -- registers the logger with Log4j
    RETURN name
END FUNCTION

#+ The conventional root-logger handle (NULL name -> root logger).
PUBLIC FUNCTION getRootLogger() RETURNS STRING
    RETURN NULL
END FUNCTION

PUBLIC FUNCTION trace(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.trace(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION debug(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.debug(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION info(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.info(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION warn(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.warn(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION error(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.error(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION fatal(name STRING, message STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        CALL lgr.fatal(message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ Log at an arbitrary level given by name (TRACE/DEBUG/INFO/WARN/ERROR/FATAL).
#+ An unknown level name is a no-op and is recorded in getLastError().
PUBLIC FUNCTION log(name STRING, levelName STRING, message STRING)
    DEFINE lgr Logger
    DEFINE lvl Level
    TRY
        LET lvl = resolveLevel(levelName)
        IF lvl IS NULL THEN
            LET m_lastError = SFMT("Unknown log level: %1", levelName)
            RETURN
        END IF
        LET lgr = resolveLogger(name)
        CALL lgr.log(lvl, message)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ Convert a BDL DYNAMIC ARRAY OF STRING into a Java Object[] for Log4j's
#+ "{}" substitution. (A DYNAMIC ARRAY cannot be passed to Java directly;
#+ a fixed Java array must be allocated with create(length).)
PRIVATE FUNCTION buildArgs(args DYNAMIC ARRAY OF STRING) RETURNS objArray
    DEFINE ja objArray
    DEFINE i INTEGER
    LET ja = objArray.create(args.getLength())
    FOR i = 1 TO args.getLength()
        LET ja[i] = args[i]   -- STRING widens to java.lang.Object
    END FOR
    RETURN ja
END FUNCTION

PUBLIC FUNCTION tracep(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.trace(message)
        ELSE
            CALL lgr.trace(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION debugp(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.debug(message)
        ELSE
            CALL lgr.debug(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION infop(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.info(message)
        ELSE
            CALL lgr.info(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION warnp(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.warn(message)
        ELSE
            CALL lgr.warn(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION errorp(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.error(message)
        ELSE
            CALL lgr.error(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

PUBLIC FUNCTION fatalp(name STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    TRY
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.fatal(message)
        ELSE
            CALL lgr.fatal(message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ Parameterized variant of log(): "{}" placeholders in message are filled
#+ from args in order. An unknown level name is a no-op recorded in getLastError().
PUBLIC FUNCTION logp(
    name STRING, levelName STRING, message STRING, args DYNAMIC ARRAY OF STRING)
    DEFINE lgr Logger
    DEFINE lvl Level
    TRY
        LET lvl = resolveLevel(levelName)
        IF lvl IS NULL THEN
            LET m_lastError = SFMT("Unknown log level: %1", levelName)
            RETURN
        END IF
        LET lgr = resolveLogger(name)
        IF args.getLength() == 0 THEN
            CALL lgr.log(lvl, message)
        ELSE
            CALL lgr.log(lvl, message, buildArgs(args))
        END IF
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ TRUE if the named logger would emit at the given level.
#+ Lets callers skip building an expensive message when it would be discarded.
PUBLIC FUNCTION isEnabled(name STRING, levelName STRING) RETURNS BOOLEAN
    DEFINE lgr Logger
    DEFINE lvl Level
    TRY
        LET lvl = resolveLevel(levelName)
        IF lvl IS NULL THEN
            LET m_lastError = SFMT("Unknown log level: %1", levelName)
            RETURN FALSE
        END IF
        LET lgr = resolveLogger(name)
        RETURN lgr.isEnabled(lvl)
    CATCH
        LET m_lastError = err_get(status)
        RETURN FALSE
    END TRY
END FUNCTION

#+ Apply a level to a logger config, editing the *running* configuration.
#+
#+ We deliberately do NOT use org.apache.logging.log4j.core.config.Configurator:
#+ its setLevel/setRootLevel call LoggerContext.getContext(false), which infers
#+ the LoggerContext from the immediate caller's classloader -- inside log4j-core
#+ that is not the context our loggers live in under the Genero Java bridge, so
#+ the change is silently applied to the wrong context and has no effect.
#+
#+ Instead we resolve the context from OUR own caller (this module), fetch its
#+ Configuration, and set the level on the matching LoggerConfig -- creating one
#+ (additive, so it still inherits the root appenders) when no exact config
#+ exists -- then refresh the live loggers.
#+
#+ A root-logger level change is just name = "" (the root LoggerConfig name).
PRIVATE FUNCTION applyLevel(name STRING, lvl Level)
    DEFINE ctx LoggerContext
    DEFINE cfg Configuration
    DEFINE lc LoggerConfig
    DEFINE key STRING

    LET key = NVL(name, "")
    LET ctx = CAST(LogManager.getContext(FALSE) AS LoggerContext)
    LET cfg = ctx.getConfiguration()
    LET lc = cfg.getLoggerConfig(key)
    IF lc.getName() != key THEN
        -- No exact config for this name: add one (additive => inherits root appenders).
        LET lc = LoggerConfig.create(key, lvl, TRUE)
        CALL cfg.addLogger(key, lc)
    ELSE
        CALL lc.setLevel(lvl)
    END IF
    CALL ctx.updateLoggers()
END FUNCTION

#+ Programmatically set the level of a named logger. Takes effect immediately.
PUBLIC FUNCTION setLevel(name STRING, levelName STRING)
    DEFINE lvl Level
    TRY
        LET lvl = resolveLevel(levelName)
        IF lvl IS NULL THEN
            LET m_lastError = SFMT("Unknown log level: %1", levelName)
            RETURN
        END IF
        CALL applyLevel(name, lvl)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ Programmatically set the root logger's level. Takes effect immediately.
PUBLIC FUNCTION setRootLevel(levelName STRING)
    DEFINE lvl Level
    TRY
        LET lvl = resolveLevel(levelName)
        IF lvl IS NULL THEN
            LET m_lastError = SFMT("Unknown log level: %1", levelName)
            RETURN
        END IF
        CALL applyLevel("", lvl)
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ Flush and stop the Log4j logging system. Call once before the program
#+ exits to ensure buffered/asynchronous appenders write their output.
PUBLIC FUNCTION shutdown()
    TRY
        CALL LogManager.shutdown()
    CATCH
        LET m_lastError = err_get(status)
    END TRY
END FUNCTION

#+ The message from the most recent failed Log4j call (NULL if none).
PUBLIC FUNCTION getLastError() RETURNS STRING
    RETURN m_lastError
END FUNCTION
