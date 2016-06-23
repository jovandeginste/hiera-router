require 'rubygems'

spec = Gem::Specification.new do |gem|
	gem.name = "hiera-router"
	gem.version = "0.1.0"
	gem.license = "Apache-2.0"
	gem.summary = "This hiera backend to selectively forward requests to different hiera backends"
	gem.email = ["jo.vandeginste@kuleuven.be", "tom.leuse@kuleuven.be"]
	gem.authors = ["Jo Vandeginste", "Tom Leuse"]
	gem.homepage = "https://github.com/jovandeginste/hiera-router"
	gem.description = File.read('README.md')
	gem.require_path = "lib"
	gem.files = Dir["lib/**/*"]
end
