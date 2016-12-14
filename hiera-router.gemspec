require 'rubygems'

spec = Gem::Specification.new do |gem|
	gem.name = "hiera-router"
	gem.version = "0.2.6"
	gem.license = "Apache-2.0"
	gem.summary = "This hiera backend to selectively forward requests to different hiera backends"
	gem.email = ["jo.vandeginste@kuleuven.be", "tom.leuse@kuleuven.be"]
	gem.authors = ["Jo Vandeginste", "Tom Leuse"]
	gem.homepage = "https://github.com/jovandeginste/hiera-router"
	gem.description = <<-DESCR
This hiera backend replaces the default yaml backend, but will resend queries to other hiera backends based on the value returned by the yaml files.

When hiera-router gets a string matching "backend[otherbackendname]", it will resend the same query to "otherbackendname".
	DESCR
	gem.require_path = "lib"
	gem.files = Dir["lib/**/*"]
end
