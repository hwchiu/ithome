all:
	gitbook build
	cp -R _book/* .
	git clean -fx _book
