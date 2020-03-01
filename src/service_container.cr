# Where the instantiated services live.
#
# A getter is defined for each service, if it is public.
# Otherwise, services are only available via constructor DI.
struct Athena::DependencyInjection::ServiceContainer
  private macro stringify(string)
    string.is_a?(StringLiteral) ? string : string.stringify
  end

  private macro is_optional_service(arg)
    arg.is_a?(StringLiteral) && arg.starts_with?("@?")
  end

  private macro is_service(arg)
    arg.is_a?(StringLiteral) && arg.starts_with?('@')
  end

  private macro is_tagged_service(arg)
    arg.is_a?(StringLiteral) && arg.starts_with?('!')
  end

  private macro get_service_id(service, service_ann)
    @type.stringify(service_ann && service_ann[:name] ? service_ann[:name] : service.name.gsub(/::/, "_").underscore)
  end

  private macro get_service_hash_value(service_id, service, service_ann, alias_hash)
    if service_ann && service_ann[:alias] != nil
      alias_hash[service_ann[:alias].resolve] = service_id
    end

    {
      lazy: (service_ann && service_ann[:lazy]) || false,
      public: (service_ann && service_ann[:public]) || false,
      alias_public: (service_ann && service_ann[:alias_public]) || false,
      tags: (service_ann && service_ann[:tags]) || [] of Nil,
      type: service.resolve,
      service_annotation: service_ann
    }
  end

  private macro get_initializer_args(service)
    initializer = service.methods.find(&.annotation(ADI::Inject)) || service.methods.find(&.name.==("initialize"))
    (i = initializer) ? i.args : [] of Nil
  end

  private macro resolve_dependencies(service_hash, alias_hash, service, service_ann)
    # If positional arguments are provided,
    # use them to instantiate the object
    if service_ann && !service_ann.args.empty?
      service_ann.args.map_with_index do |arg, idx|
       @type.parse_arg service_hash, service, arg, idx
      end
    else
      # Otherwise, try and auto resolve the arguments
      @type.get_initializer_args(service).map_with_index do |arg, idx|
        # Check if an explicit value was passed for this arg
        if service_ann && service_ann.named_args.keys.includes? "_#{arg.name}".id
          @type.parse_arg service_hash, service, service_ann.named_args["_#{arg.name}"], idx
        else
          resolved_services = [] of Nil

          # Otherwise resolve possible services based on type
          service_hash.each do |service_id, metadata|
            if metadata[:type] <= arg.restriction.resolve
              resolved_services << service_id
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
    end
  end

  private macro resolve_tags(service_hash, tag)
    tagged_services = [] of Nil
    service_hash.each do |service_id, metadata|
      tagged_services << service_id.id if metadata[:tags].includes? tag
    end
    tagged_services
  end

  private macro parse_arg(service_hash, service, arg, idx)
    if arg.is_a?(ArrayLiteral)
      %(#{arg.map_with_index { |arr_arg, arr_idx| @type.parse_arg service_hash, service, arr_arg, arr_idx }} of Union(#{@type.get_initializer_args(service)[idx].restriction.resolve.type_vars.splat})).id
    elsif @type.is_optional_service arg
      service_id = arg[2..-1]

      if s = service_hash[service_id]
        "#{service_id.id}".id
      else
        nil
      end
    elsif @type.is_service arg
      "#{arg[1..-1].id}".id
    elsif @type.is_tagged_service arg
      %(#{@type.resolve_tags service_hash, arg[1..-1]} of Union(#{@type.get_initializer_args(service)[idx].restriction.resolve.type_vars.splat})).id
    else
      arg
    end
  end

  macro finished
    {% begin %}
      # Define a hash to store services while the container is being built
      # Key is the ID of the service and the value is another hash containing its arguments, type, etc.
      {% service_hash = {} of Nil => Nil %}

      # Define a hash to map alias types to a service ID.
      {% alias_hash = {} of Nil => Nil %}

      # Register each service in the hash along with some related metadata.
      {% for service in ADI::Service.includers %}
        {% raise "#{service.name} includes `ADI::Service` but is not registered.  Did you forget the annotation?" if (annotations = service.annotations(ADI::Register)) && annotations.empty? && !service.abstract? %}
        {% for ann in annotations %}
          {% service_id = @type.get_service_id service, ann %}
          {% service_hash[service_id] = @type.get_service_hash_value service_id, service, ann, alias_hash %}
        {% end %}
      {% end %}

      # Run pre process compiler pass
      {% for pass in ADI::CompilerPass.includers %}
        {% pass.pre_process service_hash, alias_hash %}
      {% end %}

      # Resolve the arguments for each service
      {% for service_id, metadata in service_hash %}
        {% service_hash[service_id][:arguments] = @type.resolve_dependencies service_hash, alias_hash, metadata[:type], metadata[:service_annotation] %}
      {% end %}

      # Run post process compiler pass
      {% for pass in ADI::CompilerPass.includers %}
        {% pass.post_process service_hash, alias_hash %}
      {% end %}

      # Define a getter for the service, public if the service is public
      # If the service is public, also define a getter to get it via type
      {% for service_id, metadata in service_hash %}
        {% if metadata[:public] != true %}private{% end %} getter {{service_id.id}} : {{metadata[:type]}} { {{metadata[:type]}}.new({{metadata[:arguments].splat}}) }

        {% if metadata[:public] %}
          def get(service : {{metadata[:type]}}.class) : {{metadata[:type]}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Also define a getter for public aliases
      {% for service_type, service_id in alias_hash %}
        {% service = service_hash[service_id] %}
        {% if service[:alias_public] == true %}
          def {{@type.get_service_key(service_type, nil).id}} : {{service[:type]}}
            {{service_id.id}}
          end

          def get(service : {{service_type}}.class) : {{service[:type]}}
            {{service_id.id}}
          end
        {% end %}
      {% end %}

      # Initializes the container.  Auto registering annotated services.
      def initialize
        # Work around for https://github.com/crystal-lang/crystal/issues/7975.
        {{@type}}

        # Initialize non lazy services
        {% for service_id, metadata in service_hash %}
          {% if metadata[:lazy] != true %}
            @{{service_id.id}} = {{service_id.id}}
          {% end %}
        {% end %}
      end
      {{debug}}
    {% end %}
  end
end
