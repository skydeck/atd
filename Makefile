# $Id: Makefile 52901 2010-12-10 18:47:39Z martin $

VERSION = 1.0.0

SOURCES = \
  atd_version.ml \
  atd_ast.mli atd_ast.ml \
  atd_annot.mli atd_annot.ml \
  atd_parser.mli atd_parser.mly \
  atd_lexer.mll \
  atd_print.mli atd_print.ml \
  atd_predef.ml \
  atd_check.ml \
  atd_expand.mli atd_expand.ml \
  atd_inherit.mli atd_inherit.ml \
  atd_tsort.mli atd_tsort.ml \
  atd_util.mli atd_util.ml \
  atd_reflect.mli atd_reflect.ml \
  atd_indent.mli atd_indent.ml

MLY = $(filter %.mly, $(SOURCES))
MLL = $(filter %.mll, $(SOURCES))

MLSOURCES = $(patsubst %.mll,%.ml, $(patsubst %.mly,%.ml, $(SOURCES)))
MLI = $(filter %.mli, $(MLSOURCES))
ML = $(filter %.ml, $(MLSOURCES))
CMI = $(patsubst %.ml,%.cmi, $(ML))
CMO = $(patsubst %.ml,%.cmo, $(ML))
CMX = $(patsubst %.ml,%.cmx, $(ML))
O = $(patsubst %.ml,%.o, $(ML))

OCAMLFLAGS = -dtypes -g
OCAMLPACKS = easy-format unix

DOCFILES = \
  atd_ast \
  atd_annot \
  atd_print \
  atd_expand \
  atd_inherit \
  atd_util \
  atd_reflect \
  atd_indent

DOCSOURCES = $(addsuffix .mli, $(DOCFILES))

ifndef PREFIX
  PREFIX = $(shell dirname $$(dirname $$(which ocamlfind)))
  export PREFIX
endif

ifndef BINDIR
  BINDIR = $(PREFIX)/bin
  export BINDIR
endif

.PHONY: default all opt install uninstall

default: all opt

all: META atd.cma

opt: META atd.cmxa atdcat

install: META
	test ! -f atdcat || cp atdcat $(BINDIR)/
	test ! -f atdcat.exe || cp atdcat.exe $(BINDIR)/
	ocamlfind install atd META \
		`find $(MLI) $(CMI) $(CMO) $(CMX) $(O) atd.cma atd.a atd.cmxa`

uninstall:
	test ! -f $(BINDIR)/atdcat || rm $(BINDIR)/atdcat
	test ! -f $(BINDIR)/atdcat.exe || rm $(BINDIR)/atdcat.exe 
	ocamlfind remove atd

atd_version.ml: Makefile
	echo 'let version = "$(VERSION)"' > atd_version.ml

META: META.in Makefile
	echo 'version = "$(VERSION)"' > META
	cat META.in >> META

%.cmi: %.mli
	ocamlfind ocamlc $(OCAMLFLAGS) -c -package "$(OCAMLPACKS)" $<

%.cmi: %.ml
	ocamlfind ocamlc $(OCAMLFLAGS) -c -package "$(OCAMLPACKS)" $<

%.cmo: %.ml
	ocamlfind ocamlc $(OCAMLFLAGS) -c -package "$(OCAMLPACKS)" $<

%.cmx: %.ml
	ocamlfind ocamlopt $(OCAMLFLAGS) -c -package "$(OCAMLPACKS)" $<

atd_parser.mli: atd_parser.mly
	menhir $<

atd_parser.ml: atd_parser.mly
	menhir $<

atd_lexer.ml: atd_lexer.mll
	ocamllex $<

dep: $(SOURCES) Makefile
	ocamlfind ocamldep -package "$(OCAMLPACKS)" $(MLI) $(ML) > dep

ifneq ($(MAKECMDGOALS),clean)
-include dep
endif

atd.cma: dep $(CMI) $(CMO)
	ocamlfind ocamlc $(OCAMLFLAGS) -o atd.cma -a $(CMO)

atd.cmxa: dep $(CMI) $(CMX)
	ocamlfind ocamlopt $(OCAMLFLAGS) -o atd.cmxa -a $(CMX)

atdcat: dep $(CMI) $(CMX) atdcat.ml
	ocamlfind ocamlopt $(OCAMLFLAGS) -o atdcat \
		-package "$(OCAMLPACKS)" -linkpkg \
		$(CMX) atdcat.ml

.PHONY: doc
doc: odoc/index.html atdcat
	cd manual; $(MAKE)

odoc/index.html: $(CMI)
	mkdir -p odoc
	ocamlfind ocamldoc -d odoc -html \
		-t 'ATD library documentation' \
		-package "$(OCAMLPACKS)" $(DOCSOURCES)

.PHONY: test
test: atdcat test.atd test2.atd
	./atdcat test.atd > test.out
	./atdcat test.out > test.out.out
	cmp test.out test.out.out
	./atdcat -x test2.atd > test2.out

.PHONY: clean
clean:
	rm -f dep
	rm -f $(CMI) $(CMO) $(CMX) $(O)
	rm -f $(patsubst %.mly,%.mli, $(MLY))
	rm -f $(patsubst %.mly,%.ml, $(MLY))
	rm -f $(patsubst %.mll,%.ml, $(MLL))
	rm -f atdcat.cm[ioxa] atdcat.o atdcat.cma atdcat.cmxa
	rm -rf odoc
	cd manual; $(MAKE) clean

.PHONY: release
release:
	svn up
	$(MAKE) doc
	test -z "$$(svn status -q)" || exit 1
	rm -rf release/atd-$(VERSION)
	mkdir -p release/atd-$(VERSION)
	mkdir -p release/atd-$(VERSION)/odoc
	mkdir -p release/atd-$(VERSION)/manual
	find `svn ls | grep -v manual` | cpio -pvd release/atd-$(VERSION)
	cd manual; find `svn ls` | cpio -pvd ../release/atd-$(VERSION)/manual
	cp manual/atd-manual.pdf release/atd-$(VERSION)/manual
	cp manual/atd-manual.txt release/atd-$(VERSION)/manual
	cp manual/atd-manual.html release/atd-$(VERSION)/manual
	find odoc/* | cpio -pvd release/atd-$(VERSION)
	cd release && tar czf atd-$(VERSION).tar.gz atd-$(VERSION)