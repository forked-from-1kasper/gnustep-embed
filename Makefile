CC        ?= cc
BINARY     = gnustep-embed
SRCDIR     = source
BUILDDIR   = build
INCLUDEDIR = include
MFILES     = $(shell find $(SRCDIR) -type f -name '*.m')
MFLAGS     = -std=gnu2x $(shell gnustep-config --objc-flags)
LDFLAGS    = $(shell gnustep-config --gui-libs) -lX11
OMFILES    = $(MFILES:$(SRCDIR)/%.m=$(BUILDDIR)/%.o)

all: $(BUILDDIR) $(BINARY)

$(OMFILES): $(BUILDDIR)/%.o: $(SRCDIR)/%.m
	mkdir -p `dirname $@`
	$(CC) -x objective-c $(MFLAGS) -c $< -o $@ -I$(INCLUDEDIR)

$(BINARY): $(OMFILES)
	$(CC) -o $(BINARY) $(OMFILES) $(LDFLAGS)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

clean:
	rm -f $(BINARY) $(OMFILES)

run: $(BUILDDIR) $(BINARY)
	$(shell realpath $(BINARY)) -config XTerm.plist
