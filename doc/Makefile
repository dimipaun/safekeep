MAN_TXT  := $(wildcard *.txt)
DOC_HTML := $(patsubst %.txt,%.html,$(MAN_TXT))
DOC_MAN  := $(patsubst %.txt,%.1,$(MAN_TXT))

all: html man

build: all

html: $(DOC_HTML)

man: $(DOC_MAN)

clean:
	rm -f *.xml *.html *.1

$(DOC_HTML) $(DOC_MAN): asciidoc.conf

%.html: %.txt
	asciidoc -b xhtml11 -d manpage -f asciidoc.conf $<

%.1: %.xml
	xmlto -m callouts.xsl man $<

%.xml: %.txt
	asciidoc -b docbook -d manpage -f asciidoc.conf $<
