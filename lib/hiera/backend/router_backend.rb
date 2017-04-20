class Hiera
	class Config
		class << self
			def config
				@config
			end
		end
	end

	module Backend
		class Router_backend
			attr_reader :backends

			def initialize(cache = nil)
				require 'hiera/filecache'
				require 'yaml'
				@cache = cache || Filecache.new
				@backends = {}
				Hiera.debug("[hiera-router] I'm here!")
				Hiera.debug("[hiera-router] My configuration: #{Config[:router].inspect}")

				if backend_list = Config[:router][:backends]
					Hiera.debug("[hiera-router] Initializing backends: #{backend_list.keys.join(',')}")
					backend_list.each do |backend, backend_config|
						Hiera.debug("[hiera-router] Initializing backend '#{backend}'")
						backend_classname = backend_config['backend_class'] || backend_config[:backend_class] || backend
						Hiera.debug("[hiera-router] Backend class for '#{backend}' will be '#{backend_classname}'")

						backend_config = Config[:router].merge({
							:hierarchy => Config[:hierarchy],
							:backends => [backend_classname],
							backend_classname.to_sym => Config[backend_classname.to_sym] || Config[:router][backend_classname.to_sym] || {},
						})
						@backends[backend.to_sym] = {
							:class_name => "#{backend_classname.capitalize}_backend",
							:config => backend_config,
						}
					end
				end

				Hiera.debug("All the backend configs: #{@backends.inspect}")

				Hiera.debug("[hiera-router] hiera router initialized")
			end
			def lookup(key, scope, order_override, resolution_type)
				options = {
					:key => key,
					:scope => scope,
					:order_override => order_override,
					:resolution_type => resolution_type,
				}
				answer = nil

				Hiera.debug("[hiera-router] Looking up #{key} in yaml backend")

				Backend.datasources(scope, order_override) do |source|
					Hiera.debug("[hiera-router] Looking for data source #{source}")
					yaml_file = Backend.datafile(:router, scope, source, 'yaml') || next

					next unless File.exists?(yaml_file)

					data = @cache.read(yaml_file, Hash) do |cached_data|
						begin
							YAML.load(cached_data)
						rescue
							nil
						end
					end

					if data.nil?
						Hiera.debug("[hiera-router] something wrong with source #{source} '#{yaml_file}' -- returning an empty result")
						next
					end

					next if data.empty?
					next unless data.include?(key)

					Hiera.debug("[hiera-router] Found #{key} in #{source}")

					new_answer = parse_answer(data[key], scope, options)
					next if new_answer.nil?

					case resolution_type
					when :array
						raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
						answer ||= []
						answer << new_answer
					when :hash
						raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
						answer ||= {}
						answer = Backend.merge_answer(new_answer,answer)
					else
						answer = new_answer
						break
					end
				end

				return answer
			end

			def recursive_key_from_hash(hash, path)
				focus = hash
				path.each do |key|
					if focus.is_a?(Hash) and focus.include?(key)
						focus = focus[key]
					else
						return nil
					end
				end

				return focus
			end

			def parse_answer(data, scope, options, path = [])
				if data.is_a?(Numeric) or data.is_a?(TrueClass) or data.is_a?(FalseClass)
					return data
				elsif data.is_a?(String)
					return parse_string(data, scope, options, path)
				elsif data.is_a?(Hash)
					answer = {}
					data.each_pair do |key, val|
						interpolated_key = Backend.parse_string(key, scope)
						subpath = path + [interpolated_key]
						answer[interpolated_key] = parse_answer(val, scope, options, subpath)
					end

					return answer
				elsif data.is_a?(Array)
					answer = []
					data.each do |item|
						answer << parse_answer(item, scope, options)
					end

					return answer
				end
			end

			def parse_string(data, scope, options, path = [])
				if match = data.match(/^backend\[([^,]+)(?:,(.*))?\]$/)
					backend_name, backend_parameters = match.captures
					backend_options = options
					backend_options = backend_options.merge(backend_parameters) if backend_parameters
					Hiera.debug("[hiera-router] Calling hiera with '#{backend_name}'...")
					if backend = backends[backend_name.to_sym]
						backend_classname = backend[:class_name]
						Hiera.debug("[hiera-router] Backend class: #{backend_classname}")
						config = Config.config
						Config.load(backend[:config])
						require "hiera/backend/#{backend_classname.downcase}"
						result = Hiera::Backend.const_get(backend_classname).new.lookup(backend_options[:key], backend_options[:scope], nil, backend_options[:resolution_type])
						Config.load(config)
					else
						Hiera.warn "Backend '#{backend_name}' was not configured; returning the data as-is."
						result = data
					end
					Hiera.debug("[hiera-router] Call to '#{backend_name}' finished.")
					return recursive_key_from_hash(result, path)
				else
					Backend.parse_string(data, scope)
				end
			end
		end
	end
end
