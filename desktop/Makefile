# Sources for desktop

S_DESKTOP := cookies.c history_global_core.c hotlist.c knockout.c	\
	mouse.c options.c plot_style.c print.c search.c searchweb.c	\
	scrollbar.c sslcert.c textarea.c thumbnail.c tree.c 		\
	tree_url_node.c version.c

S_DESKTOP := $(addprefix desktop/,$(S_DESKTOP))

# version.c needs the testament
desktop/version.c: testament utils/testament.h

# S_BROWSER are sources related to full browsers but are common
# between RISC OS, GTK, BeOS and AmigaOS builds
S_BROWSER := browser.c download.c frames.c history_core.c netsurf.c \
	save_complete.c save_text.c selection.c textinput.c

S_BROWSER := $(addprefix desktop/,$(S_BROWSER))

