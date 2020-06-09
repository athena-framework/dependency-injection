# Where the instantiated services live.
#
# If a service is public, a getter based on the service's name as well as its type is defined.  Otherwise, services are only available via constructor DI.
#
# TODO: Reduce the amount of duplication when [this issue](https://github.com/crystal-lang/crystal/pull/9091) is resolved.
class Athena::DependencyInjection::ServiceContainer
  macro finished
    {% begin %}
      # Define a hash to store services while the container is being built
      # Key is the ID of the service and the value is another hash containing its arguments, type, etc.
      {% service_hash = {} of Nil => Nil %}

      # Define a hash to map alias types to a service ID.
      {% alias_hash = {} of Nil => Nil %}

      # Register each service in the hash along with some related metadata.
      {% for service in Object.all_subclasses.select &.annotation(ADI::Register) %}
        {% if (annotations = service.annotations(ADI::Register)) && !annotations.empty? && !service.abstract? %}
          # Raise a compile time exception if multiple services are based on this type, and not all of them specify a `name`.
          {% if annotations.size > 1 && !annotations.all? &.[:name] %}
            {% service.raise "Failed to register services for '#{service}'.  Services based on this type must each explicitly provide a name." %}
          {% end %}

          {% auto_configuration = (key = AUTO_CONFIGURATIONS.keys.find &.>=(service.resolve)) ? AUTO_CONFIGURATIONS[key] : {} of Nil => Nil %}

          {% for ann in annotations %}
            # If positional arguments are provided, use them as generic arguments
            {% generics = ann.args %}

            # Use the service name defined within the annotation, otherwise fallback on FQN snake cased
            {% id_key = ann[:name] || service.name.gsub(/::/, "_").underscore %}
            {% service_id = id_key.is_a?(StringLiteral) ? id_key : id_key.stringify %}
            {% tags = [] of Nil %}

            {% if !service.type_vars.empty? && (ann && !ann[:name]) %}
              {% service.raise "Failed to register services for '#{service}'.  Generic services must explicitly provide a name." %}
            {% end %}

            {% if !service.type_vars.empty? && generics.empty? %}
              {% service.raise "Failed to register service '#{service_id.id}'.  Generic services must provide the types to use via the 'generics' field." %}
            {% end %}

            {% if service.type_vars.size != generics.size %}
              {% service.raise "Failed to register service '#{service_id.id}'.  Expected #{service.type_vars.size} generics types got #{generics.size}." %}
            {% end %}

            {% if ann && ann[:alias] != nil %}
              {% alias_hash[ann[:alias].resolve] = service_id %}
            {% end %}

            {% if (ann_tags = ann[:tags]) || (ann_tags = auto_configuration[:tags]) %}
              {% ann.raise "Failed to register service `#{service_id.id}`.  Tags must be an ArrayLiteral or TupleLiteral, not #{ann_tags.class_name.id}." unless ann_tags.is_a? ArrayLiteral %}
              {% tags = ann_tags.map do |tag|
                   if tag.is_a? StringLiteral
                     {name: tag}
                   elsif tag.is_a? Path
                     {name: tag.resolve}
                   elsif tag.is_a? NamedTupleLiteral
                     tag.raise "Failed to register service `#{service_id.id}`.  All tags must have a name." unless tag[:name]

                     # Resolve a constant to its value if used as a tag name
                     if tag[:name].is_a? Path
                       tag[:name] = tag[:name].resolve
                     end

                     tag
                   else
                     tag.raise "Failed to register service `#{service_id.id}`.  A tag must be a StringLiteral or NamedTupleLiteral not #{tag.class_name.id}."
                   end
                 end %}
            {% end %}

              {%
                service_hash[service_id] = {
                  generics:           generics,
                  lazy:               ann[:lazy] != nil ? ann[:lazy] : (auto_configuration[:lazy] != nil ? auto_configuration[:lazy] : true),
                  public:             ann[:public] != nil ? ann[:public] : (auto_configuration[:public] != nil ? auto_configuration[:public] : false),
                  public_alias:       ann[:public_alias] != nil ? ann[:public_alias] : false,
                  service_annotation: ann,
                  tags:               tags,
                  type:               service.resolve,
                }
              %}
          {% end %}
        {% end %}
      {% end %}

      # Resolve the arguments for each service
      {% for service_id, metadata in service_hash %}
        {% service_ann = metadata[:service_annotation] %}
        {% service = metadata[:type] %}
        {% initializer = service.methods.find(&.annotation(ADI::Inject)) || service.methods.find(&.name.==("initialize")) %}
        {% initializer_args = (i = initializer) ? i.args : [] of Nil %}

        {%
          arguments = initializer_args.map_with_index do |initializer_arg, idx|
            # Check if an explicit value was passed for this initializer_arg
            if service_ann && service_ann.named_args.keys.includes? "_#{initializer_arg.name}".id
              named_arg = service_ann.named_args["_#{initializer_arg.name}"]

              if named_arg.is_a?(ArrayLiteral)
                inner_args = named_arg.map do |arr_arg|
                  if arr_arg.is_a?(ArrayLiteral)
                    arr_arg.raise "Failed to register service '#{service_id.id}'.  Arrays more than two levels deep are not currently supported."
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('@')
                    service_name = arr_arg[1..-1]
                    raise "Failed to register service '#{service_id.id}'.  Could not resolve argument '#{initializer_arg}' from named argument value '#{named_arg}'." unless service_hash[service_name]
                    service_name.id
                  else
                    arr_arg
                  end
                end

                %(#{inner_args} of Union(#{initializer_arg.restriction.resolve.type_vars.splat})).id
              elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?('!')
                tagged_services = [] of Nil

                # Build an array of services with the given tag, along with the tag metadata
                service_hash.each do |id, s_metadata|
                  if t = s_metadata[:tags].find { |tag| tag[:name] == named_arg[1..-1] }
                    tagged_services << {id.id, t}
                  end
                end

                # Sort based on tag priority.  Services without a priority will be last in order of definition
                tagged_services = tagged_services.sort_by { |item| -(item[1][:priority] || 0) }

                %(#{tagged_services.map(&.first)} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
              else
                named_arg
              end
            elsif (bindings = BINDINGS[initializer_arg.name.stringify]) && # Check if there are any bindings defined for this argument
                  (
                    (binding = bindings[:typed].find &.[:type].<=(initializer_arg.restriction.resolve)) || # First try resolving it via a typed bindings since they are more specific
                    (binding = bindings[:untyped].first)                                                   # Otherwise fallback on last defined untyped binding (they're pushed in reverse order)
                  )
              binding_value = binding[:value]

              if binding_value.is_a?(ArrayLiteral)
                inner_binding_args = binding_value.map do |arr_arg|
                  if arr_arg.is_a?(ArrayLiteral)
                    arr_arg.raise "Failed to register service '#{service_id.id}'.  Arrays more than two levels deep are not currently supported."
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('@')
                    service_name = arr_arg[1..-1]
                    raise "Failed to register service '#{service_id.id}'.  Could not resolve argument '#{initializer_arg}' from binding value '#{binding_value}'." unless service_hash[service_name]
                    service_name.id
                  else
                    arr_arg
                  end
                end

                %(#{inner_binding_args} of Union(#{initializer_arg.restriction.resolve.type_vars.splat})).id
              elsif binding_value.is_a?(StringLiteral) && binding_value.starts_with?('!')
                tagged_services = [] of Nil

                # Build an array of services with the given tag, along with the tag metadata
                service_hash.each do |id, s_metadata|
                  if t = s_metadata[:tags].find { |tag| tag[:name] == binding_value[1..-1] }
                    tagged_services << {id.id, t}
                  end
                end

                # Sort based on tag priority.  Services without a priority will be last in order of definition
                tagged_services = tagged_services.sort_by { |item| -(item[1][:priority] || 0) }

                %(#{tagged_services.map(&.first)} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
              else
                binding_value
              end
            else
              resolved_services = [] of Nil

              # Otherwise resolve possible services based on type
              service_hash.each do |id, s_metadata|
                if (type = initializer_arg.restriction.resolve?) && s_metadata[:type] <= type
                  resolved_services << id
                end
              end

              # If no services could be resolved
              if resolved_services.size == 0
                # Return a default value if any
                if !initializer_arg.default_value.is_a? Nop
                  initializer_arg.default_value
                  # including `nil` if thats a possibility
                elsif initializer_arg.restriction.resolve.nilable?
                  nil
                else
                  # otherwise raise an exception
                  initializer_arg.raise "Failed to auto register service '#{service_id.id}'.  Could not resolve argument '#{initializer_arg}'."
                end
              elsif resolved_services.size == 1
                # If only one was matched, return it
                resolved_services[0].id
              else
                # Otherwise fallback on the argument's name as well
                if resolved_service = resolved_services.find(&.==(initializer_arg.name))
                  resolved_service.id
                  # If no service with that name could be resolved, check the alias map for the restriction
                elsif aliased_service = alias_hash[initializer_arg.restriction.resolve]
                  # If one is found returned the aliased service
                  aliased_service.id
                else
                  # Otherwise raise an exception
                  initializer_arg.raise "Failed to auto register service '#{service_id.id}'.  Could not resolve argument '#{initializer_arg}'."
                end
              end
            end
          end
        %}

        {% service_hash[service_id][:arguments] = arguments %}
      {% end %}

      # Define getters for each service, if the service is public, make the getter public and also define a type based getter
      {% for service_id, metadata in service_hash %}
        {% type = metadata[:generics].empty? ? metadata[:type] : "#{metadata[:type].name(generic_args: false)}(#{metadata[:generics].splat})".id %}

        {% if metadata[:public] != true %}private{% end %} getter {{service_id.id}} : {{type}} { {{type}}.new({{metadata[:arguments].splat}}) }

        {% if metadata[:public] %}
          def get(service : {{type}}.class) : {{type}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Define getters for aliased service, if the alias is public, make the getter public and also define a type based getter
      {% for service_type, service_id in alias_hash %}
        {% metadata = service_hash[service_id] %}

        {% type = metadata[:generics].empty? ? metadata[:type] : "#{metadata[:type].name(generic_args: false)}(#{metadata[:generics].splat})".id %}

        {% if metadata[:public_alias] != true %}private{% end %} def {{service_type.name.gsub(/::/, "_").underscore.id}} : {{type}}; {{service_id.id}}; end

        {% if metadata[:public_alias] %}
          def get(service : {{service_type}}.class) : {{service_type}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Initializes the container.  Auto registering annotated services.
      def initialize
        # Work around for https://github.com/crystal-lang/crystal/issues/7975
        {{@type}}

        # Initialize non lazy services
        {% for service_id, metadata in service_hash %}
          {% unless metadata[:lazy] == true %}
            @{{service_id.id}} = {{service_id.id}}
          {% end %}
        {% end %}
      end
    {% end %}
  end
end
