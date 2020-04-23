# Where the instantiated services live.
#
# A getter is defined for each service, if it is public.
# Otherwise, services are only available via constructor DI.
#
# TODO: Reduce the amount of duplication when https://github.com/crystal-lang/crystal/pull/9091 is released.
struct Athena::DependencyInjection::ServiceContainer
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
          {% for ann in annotations %}
            {% generics = ann.args %}
            {% id_key = ann[:name] || service.name.gsub(/::/, "_").underscore %}
            {% service_id = id_key.is_a?(StringLiteral) ? id_key : id_key.stringify %}
            {% tags = [] of Nil %}

            {% if !service.type_vars.empty? && (ann && !ann[:name]) %}
              {% raise "Failed to register service '#{service}'.  Generic services must explicitly provide a name." %}
            {% end %}

            {% if !service.type_vars.empty? && generics.empty? %}
              {% raise "Failed to register service '#{service_id.id}'.  Generic services must provide the types to use via the 'generics' field." %}
            {% end %}

            {% if service.type_vars.size != generics.size %}
              {% raise "Failed to register service '#{service_id.id}'.  Expected #{service.type_vars.size} generics types got #{generics.size}." %}
            {% end %}

            {% if ann && ann[:alias] != nil %}
              {% alias_hash[ann[:alias].resolve] = service_id %}
            {% end %}

            {% if ann_tags = ann[:tags] %}
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
                  lazy:               (ann && ann[:lazy]) || false,
                  public:             (ann && ann[:public]) || false,
                  public_alias:       (ann && ann[:public_alias]) || false,
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

        # If positional arguments are provided,
        # use them to instantiate the object
        # Otherwise, try and auto resolve the arguments
        {%
          arguments = initializer_args.map_with_index do |initializer_arg, idx|
            # Check if an explicit value was passed for this initializer_arg
            if service_ann && service_ann.named_args.keys.includes? "_#{initializer_arg.name}".id
              named_arg = service_ann.named_args["_#{initializer_arg.name}"]

              if named_arg.is_a?(ArrayLiteral)
                inner_args = named_arg.map_with_index do |arr_arg, arr_idx|
                  if arr_arg.is_a?(ArrayLiteral)
                    arr_arg.raise "Failed to register service '#{service_id.id}'.  Arrays more than two levels deep are not currently supported."
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?("@?")
                    s_id = arr_arg[2..-1]

                    (s = service_hash[s_id]) ? s_id.id : nil
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('@')
                    service_name = arr_arg[1..-1]
                    raise "Failed to register service '#{service_name.id}'.  Could not resolve argument '#{initializer_arg}' from '#{arr_arg.id}'." unless service_hash[service_name]
                    service_name.id
                  else
                    arr_arg
                  end
                end

                %(#{inner_args} of Union(#{initializer_arg.restriction.resolve.type_vars.splat})).id
              elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?("@?")
                s_id = named_arg[2..-1]

                (s = service_hash[s_id]) ? s_id.id : nil
              elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?('@')
                service_name = named_arg[1..-1]
                raise "Failed to register service '#{service_name.id}'.  Could not resolve argument '#{initializer_arg}' from '#{named_arg.id}'." unless service_hash[service_name]
                service_name.id
              elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?('!')
                tagged_services = [] of Nil

                # Build an array of services with the given tag,
                # along with the tag metadata
                service_hash.each do |s_id, metadata|
                  if t = metadata[:tags].find { |tag| tag[:name] == named_arg[1..-1] }
                    tagged_services << {s_id.id, t}
                  end
                end

                # Sort based on tag priority.  Services without a priority will be last in order of definition
                tagged_services = tagged_services.sort_by { |item| -(item[1][:priority] || 0) }

                %(#{tagged_services.map(&.first)} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
              else
                named_arg
              end
            else
              resolved_services = [] of Nil

              # Otherwise resolve possible services based on type
              service_hash.each do |s_id, metadata|
                if (type = initializer_arg.restriction.resolve?) && metadata[:type] <= type
                  resolved_services << s_id
                end
              end

              # If no services could be resolved
              if resolved_services.size == 0
                # Return a default value if any
                if !initializer_arg.default_value.is_a? Nop
                  initializer_arg.default_value
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
                  # If no service with that name could be resolved,
                  # check the alias map for the restriction
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
          def get(service : {{type}}.class) : {{type}}
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
