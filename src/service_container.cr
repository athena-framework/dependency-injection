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

  private macro resolve_dependencies(service_hash, service, service_ann)
    service_ann.args.map do |arg|
      @type.parse_arg service_hash, service, service_ann, arg
    end
  end

  private macro parse_arg(service_hash, service, service_ann, arg)
    if arg.is_a?(ArrayLiteral)
      arg.map { |arr_arg| parse_arg service_hash, service, service_ann, arr_arg }
    elsif @type.is_optional_service arg
      key = arg[2..-1]

      if s = service_hash[key].id
        "__#{key.id}".id
      else
        nil
      end
    elsif @type.is_service arg
      "__#{arg[1..-1].id}".id
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
          {% service_hash[@type.stringify(key)] = {lazy: ann[:lazy] || false, public: ann[:public] || false, type: service, service_annotation: ann} %}
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
        private def __{{service_id.id}} : {{metadata[:type]}}
          {{metadata[:type]}}.new({% unless metadata[:arguments].empty? %}*{{metadata[:arguments]}}{% end %})
        end

        {% if metadata[:lazy] == true %}
          @{{service_id.id}} : Proxy({{metadata[:type]}}) | {{metadata[:type]}}

          private def {{service_id.id}} : {{metadata[:type]}}
            if (service = @{{service_id.id}}) && (service.is_a? Proxy)
              @{{service_id.id}} = service.resolve
            end
            @{{service_id.id}}.as({{metadata[:type]}})
          end
        {% else %}
          @{{service_id.id}} : {{metadata[:type]}}
        {% end %}

        {% if metadata[:public] == true %}
          def {{service_id.id}} : {{metadata[:type]}}
            previous_def
          end
        {% end %}
      {% end %}

      # Initializes the container.  Auto registering annotated services.
      def initialize
        # Work around for https://github.com/crystal-lang/crystal/issues/7975.
        {{@type}}

        # define each service in the container
        {% for service_id, metadata in service_hash %}
          {% if metadata[:lazy] != true %}
            @{{service_id.id}} = __{{service_id.id}}
          {% else %}
            @{{service_id.id}} = Proxy.new ->{ __{{service_id.id}} }
          {% end %}
        {% end %}
      end

      private record Proxy(T), obj : Proc(T) do
        def resolve : T
          @obj.call
        end
      end

      {{debug}}
    {% end %}
  end
end
