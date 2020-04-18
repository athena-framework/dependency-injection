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
            {% id_key = ((ann && ann[:name]) ? ann[:name] : service.name.gsub(/::/, "_").underscore) %}
            {% service_id = id_key.is_a?(StringLiteral) ? id_key : id_key.stringify %}

            {% if ann && ann[:alias] != nil %}
              {% alias_hash[ann[:alias].resolve] = service_id %}
            {% end %}

              {%
                service_hash[service_id] = {
                  lazy:               (ann && ann[:lazy]) || false,
                  public:             (ann && ann[:public]) || false,
                  public_alias:       (ann && ann[:public_alias]) || false,
                  tags:               (ann && ann[:tags]) || [] of Nil,
                  type:               service.resolve,
                  service_annotation: ann,
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
        {% if service_ann && !service_ann.args.empty? %}
          {%
            arguments = service_ann.args.map_with_index do |arg, idx|
              if arg.is_a?(ArrayLiteral)
                inner_args = arg.map_with_index do |arr_arg, arr_idx|
                  inner_initializer = service.methods.find(&.annotation(ADI::Inject)) || service.methods.find(&.name.==("initialize"))
                  inner_initializer_args = (i = initializer) ? i.args : [] of Nil

                  if arr_arg.is_a?(ArrayLiteral)
                    arr_arg.raise "More than two level nested arrays are not currently supported"
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?("@?")
                    s_id = arr_arg[2..-1]

                    (s = service_hash[s_id]) ? s_id.id : nil
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('@')
                    arr_arg[1..-1].id
                  elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('!')
                    inner_tag = arg[1..-1]

                    inner_tagged_services = [] of Nil
                    service_hash.each do |s_id, metadata|
                      tagged_services << s_id.id if metadata[:tags].includes? arg[1..-1]
                    end
                    inner_tagged_services

                    %(#{inner_tagged_services} of Union(#{initializer_args[arr_idx].restriction.resolve.type_vars.splat})).id
                  else
                    arr_arg
                  end
                end

                %(#{inner_args} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
              elsif arg.is_a?(StringLiteral) && arg.starts_with?("@?")
                s_id = arg[2..-1]

                (s = service_hash[s_id]) ? s_id.id : nil
              elsif arg.is_a?(StringLiteral) && arg.starts_with?('@')
                arg[1..-1].id
              elsif arg.is_a?(StringLiteral) && arg.starts_with?('!')
                tag = arg[1..-1]

                tagged_services = [] of Nil
                service_hash.each do |s_id, metadata|
                  tagged_services << s_id.id if metadata[:tags].includes? arg[1..-1]
                end
                tagged_services

                %(#{tagged_services} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
              else
                arg
              end
            end
          %}
        {% else %}
          # Otherwise, try and auto resolve the arguments
          {%
            arguments = initializer_args.map_with_index do |arg, idx|
              # Check if an explicit value was passed for this arg
              if service_ann && service_ann.named_args.keys.includes? "_#{arg.name}".id
                named_arg = service_ann.named_args["_#{arg.name}"]

                if named_arg.is_a?(ArrayLiteral)
                  inner_args = arg.map_with_index do |arr_arg, arr_idx|
                    inner_initializer = service.methods.find(&.annotation(ADI::Inject)) || service.methods.find(&.name.==("initialize"))
                    inner_initializer_args = (i = initializer) ? i.args : [] of Nil

                    if arr_arg.is_a?(ArrayLiteral)
                      arr_arg.raise "More than two level nested arrays are not currently supported"
                    elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?("@?")
                      s_id = arr_arg[2..-1]

                      (s = service_hash[s_id]) ? s_id.id : nil
                    elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('@')
                      arr_arg[1..-1].id
                    elsif arr_arg.is_a?(StringLiteral) && arr_arg.starts_with?('!')
                      inner_tag = arg[1..-1]

                      inner_tagged_services = [] of Nil
                      service_hash.each do |s_id, metadata|
                        tagged_services << s_id.id if metadata[:tags].includes? arg[1..-1]
                      end
                      inner_tagged_services

                      %(#{inner_tagged_services} of Union(#{initializer_args[arr_idx].restriction.resolve.type_vars.splat})).id
                    else
                      arr_arg
                    end
                  end

                  %(#{inner_args} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
                elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?("@?")
                  s_id = named_arg[2..-1]

                  (s = service_hash[s_id]) ? s_id.id : nil
                elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?('@')
                  named_arg[1..-1].id
                elsif named_arg.is_a?(StringLiteral) && named_arg.starts_with?('!')
                  tag = named_arg[1..-1]

                  tagged_services = [] of Nil
                  service_hash.each do |s_id, metadata|
                    tagged_services << s_id.id if metadata[:tags].includes? named_arg[1..-1]
                  end
                  tagged_services

                  %(#{tagged_services} of Union(#{initializer_args[idx].restriction.resolve.type_vars.splat})).id
                else
                  named_arg
                end
              else
                resolved_services = [] of Nil

                # Otherwise resolve possible services based on type
                service_hash.each do |s_id, metadata|
                  if metadata[:type] <= arg.restriction.resolve
                    resolved_services << s_id
                  end
                end

                # If no services could be resolved
                if resolved_services.size == 0
                  # Return a default value if any
                  unless arg.default_value.is_a? Nop
                    arg.default_value
                  else
                    # otherwise raise an exception
                    arg.raise "Could not auto resolve argument #{arg}"
                  end
                elsif resolved_services.size == 1
                  # If only one was matched, return it
                  resolved_services[0].id
                else
                  # Otherwise fallback on the argument's name as well
                  if resolved_service = resolved_services.find(&.==(arg.name))
                    resolved_service.id
                    # If no service with that name could be resolved,
                    # check the alias map for the restriction
                  elsif aliased_service = alias_hash[arg.restriction.resolve]
                    # If one is found returned the aliased service
                    aliased_service.id
                  else
                    # Otherwise raise an exception
                    arg.raise "Could not auto resolve argument #{arg}"
                  end
                end
              end
            end
          %}
        {% end %}

        {% service_hash[service_id][:arguments] = arguments %}
      {% end %}

      # Define getters for each service, if the service is public, make the getter public and also define a type based getter
      {% for service_id, metadata in service_hash %}
        {% if metadata[:public] != true %}private{% end %} getter {{service_id.id}} : {{metadata[:type]}} { {{metadata[:type]}}.new({{metadata[:arguments].splat}}) }

        {% if metadata[:public] %}
          def get(service : {{metadata[:type]}}.class) : {{metadata[:type]}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Define getters for aliased service, if the alias is public, make the getter public and also define a type based getter
      {% for service_type, service_id in alias_hash %}
        {% service = service_hash[service_id] %}

        {% if service[:public_alias] != true %}private{% end %} def {{service_type.name.gsub(/::/, "_").underscore.id}} : {{service[:type]}}; {{service_id.id}}; end

        {% if service[:public_alias] == true %}
          def get(service : {{service_type}}.class) : {{service[:type]}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Initializes the container.  Auto registering annotated services.
      def initialize
        # Work around for https://github.com/crystal-lang/crystal/issues/7975.
        {{@type}}
      end
    {% end %}
  end
end
