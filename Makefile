GEMSPEC=hiera-router.gemspec
GEM_FILE_NAME=$(shell (cat $(GEMSPEC); echo "puts spec.file_name") | ruby)

gem:
	gem build $(GEMSPEC)
	gem push $(GEM_FILE_NAME)

clean:
	rm -vf *.gem
