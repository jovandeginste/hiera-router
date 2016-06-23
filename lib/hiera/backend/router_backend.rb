class Hiera
	module Backend
		class Router_backend
			attr_reader :backends

			def initialize(cache = nil)
				require 'hiera/filecache'
				require 'yaml'
				@cache = cache || Filecache.new
				@backends = {}
				if backend_list = Config[:router][:backends]
					backend_list.each do |backend|
						require "hiera/backend/#{backend.downcase}_backend"
						@backends[backend] = Hiera::Backend.const_get("#{backend.capitalize}_backend").new
					end
				end

				Hiera.debug("hiera router initialized")
			end
			def lookup(key, scope, order_override, resolution_type)
				options = {
					:key => key,
					:scope => scope,
					:order_override => order_override,
					:resolution_type => resolution_type,
				}
				answer = nil

				Hiera.debug("Looking up #{key} in yaml backend")

				Backend.datasources(scope, order_override) do |source|
					Hiera.debug("Looking for data source #{source}")
					yaml_file = Backend.datafile(:router, scope, source, 'yaml') || next

					next unless File.exists?(yaml_file)

					data = @cache.read(yaml_file, Hash) do |cached_data|
						YAML.load(cached_data) || {}
					end

					next if data.empty?
					next unless data.include?(key)

					Hiera.debug("Found #{key} in #{source}")

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

			def parse_answer(data, scope, options)
				if data.is_a?(Numeric) or data.is_a?(TrueClass) or data.is_a?(FalseClass)
					return data
				elsif data.is_a?(String)
					return parse_string(data, scope, options)
				elsif data.is_a?(Hash)
					answer = {}
					data.each_pair do |key, val|
						interpolated_key = Backend.parse_string(key, scope)
						answer[interpolated_key] = parse_answer(val, scope, options)
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

			def parse_string(data, scope, options)
				if match = data.match(/^backend\[([^,]+)(?:,(.*))?\]$/)
					backend_name, backend_parameters = match.captures
					backend_options = options
					backend_options = backend_options.merge(backend_parameters) if backend_parameters
					Hiera.debug "Calling hiera with '#{backend_name}'..."
					if backend = backends[backend_name]
						result = backend.lookup(backend_options[:key], backend_options[:scope], nil, backend_options[:resolution_type])
					else
						Hiera.warn "Backend '#{backend_name}' was not configured; returning the data as-is."
						result = data
					end
					Hiera.debug "Call to '#{backend_name}' finished."
					return result
				else
					Backend.parse_string(data, scope)
				end
			end
		end
	end
end
