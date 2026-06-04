# Makefile for fgl-log4j
#
# Builds:
#   - lib group : lib/Log4j.4gl  -> com/fourjs/log4j/Log4j.42m  (package module, no link)
#   - app group : src/log4j_test.4gl -> bin/log4j_test.42m + .42r  (test driver)
#
# Java dependencies (log4j-api / log4j-core 2.17.1) are fetched by
#   fglpkg install
# into .fglpkg/jars and put on the CLASSPATH below.

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
JARDIR   := $(CURDIR)/.fglpkg/jars
JARS     := $(wildcard $(JARDIR)/*.jar)

empty :=
space := $(empty) $(empty)

# Downloaded jars first, then bin/ (so the test app's log4j2.xml is found
# on the classpath), then any inherited CLASSPATH.
export CLASSPATH := $(subst $(space),:,$(strip $(JARS)))$(if $(JARS),:,)$(CURDIR)/bin$(if $(CLASSPATH),:$(CLASSPATH))
# Project root on FGLLDPATH so IMPORT FGL com.fourjs.log4j.* resolves.
export FGLLDPATH := $(if $(FGLLDPATH),$(FGLLDPATH):)$(CURDIR)

FGLCOMP  := fglcomp -M
FGLLINK  := fgllink

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------
PKGDIR   := com/fourjs/log4j
BINDIR   := bin

LIBMODS  := Log4j
LIB42M   := $(addprefix $(PKGDIR)/,$(addsuffix .42m,$(LIBMODS)))

APP      := log4j_test
APP42M   := $(BINDIR)/$(APP).42m
APP42R   := $(BINDIR)/$(APP).42r

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
.PHONY: all lib app run clean

all: lib app

lib: $(LIB42M)

app: $(APP42R)

# --- lib modules: source declares PACKAGE com.fourjs.log4j, so fglcomp
# appends the package path to the output dir -- output base is project root.
$(PKGDIR)/%.42m: lib/%.4gl | $(PKGDIR)
	$(FGLCOMP) -o . $<

# --- application ------------------------------------------------------------
$(APP42M): src/$(APP).4gl $(LIB42M) | $(BINDIR)
	$(FGLCOMP) -o $(BINDIR) $<

$(APP42R): $(APP42M)
	cd $(BINDIR) && $(FGLLINK) -o $(APP).42r $(APP).42m

# --- directories ------------------------------------------------------------
$(PKGDIR) $(BINDIR):
	mkdir -p $@

# --- run --------------------------------------------------------------------
run: all
	cd $(BINDIR) && FGLGUI=0 TERM=xterm fglrun $(APP).42r

# --- clean ------------------------------------------------------------------
clean:
	rm -f $(LIB42M)
	rm -f $(APP42M) $(APP42R)
