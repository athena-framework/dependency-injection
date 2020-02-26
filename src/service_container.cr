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

  private macro get_initializer_args(service)
    initializer = service.methods.find(&.annotation(ADI::Inject)) || service.methods.find(&.name.==("initialize"))
    if i = initializer
      i.args
    else
      [] of Nil
    end
  end

  private macro resolve_dependencies(service_hash, service, service_ann)
    # If positional arguments are provided,
    # use them to instantiate the object
    unless service_ann.args.empty?
      service_ann.args.map_with_index do |arg, idx|
       @type.parse_arg service_hash, service, arg, idx
      end
    else
      # Otherwise, try and auto resolve the arguments
      @type.get_initializer_args(service).map_with_index do |arg, idx|
        resolved_services = [] of Nil

        service_hash.each do |service_id, metadata|
          if metadata[:type] <= arg.restriction.resolve
            resolved_services << service_id
          end
        end

        # Check if an explicit value was passed for this arg
        if named_arg = service_ann.named_args["_#{arg.name}"]
          @type.parse_arg service_hash, service, named_arg, idx
        # If no services could be resolved
        elsif resolved_services.size == 0
          # Otherwise raise an exception
          arg.raise "Could not auto resolve argument #{arg}"  
        elsif resolved_services.size == 1
          resolved_services[0].id
        else

          resolved_services.find(&.==(arg.name)).id
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
      initializer = service.methods.find(&.name.==("initialize"))

      %(#{arg.map_with_index { |arr_arg, arr_idx| @type.parse_arg service_hash, service, arr_arg, arr_idx }} of Union(#{initializer.args[idx].restriction.resolve.type_vars.splat})).id
    elsif @type.is_optional_service arg
      key = arg[2..-1]

      if s = service_hash[key]
        "#{key.id}".id
      else
        nil
      end
    elsif @type.is_service arg
      "#{arg[1..-1].id}".id
    elsif @type.is_tagged_service arg
      @type.resolve_tags service_hash, arg[1..-1]
    else
      arg
    end
  end

  macro finished
    {% begin %}
      # Define a hash to store services while the container is being built
      # Key is the ID of the service and the value is another hash containing its arguments, type, etc.
      {% service_hash = {} of Nil => Nil %}

      # Register each service in the hash along with some related metadata.
      {% for service in ADI::Service.includers %}
        {% raise "#{service.name} includes `ADI::Service` but is not registered.  Did you forget the annotation?" if (annotations = service.annotations(ADI::Register)) && annotations.empty? && !service.abstract? %}
        {% for ann in annotations %}
          {% key = ann[:name] ? ann[:name] : service.name.split("::").last.underscore %}
          {% service_hash[@type.stringify(key)] = {lazy: ann[:lazy] || false, public: ann[:public] || false, tags: ann[:tags] || [] of Nil, type: service, service_annotation: ann} %}
        {% end %}
      {% end %}

      # Resolve the arguments for each service
      {% for service_id, metadata in service_hash %}
        {% service_hash[service_id][:arguments] = @type.resolve_dependencies service_hash, metadata[:type], metadata[:service_annotation] %}
      {% end %}

      # Run all the compiler passes
      {% for pass in ADI::CompilerPass.includers %}
        {% service_hash = pass.process(service_hash) %}
      {% end %}

      # Define getters for the services
      {% for service_id, metadata in service_hash %}
        {% if metadata[:public] != true %}private{% end %} getter {{service_id.id}} : {{metadata[:type]}} { {{metadata[:type]}}.new({{metadata[:arguments].splat}}) }
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
