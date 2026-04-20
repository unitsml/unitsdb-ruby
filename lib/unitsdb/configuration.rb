# frozen_string_literal: true

module Unitsdb
  module Configuration
    module_function

    CONTEXT_ID = :unitsdb_v2

    def context_id
      @context_id ||= CONTEXT_ID
    end

    def register_model(klass, id:)
      registered_models[id.to_sym] = klass
      klass
    end

    def registered_models
      @registered_models ||= {}
    end

    def register(id = context_id)
      explicit_registers[id.to_sym]
    end

    def populate_register(id: context_id, fallback_to: [:default], substitutions: [])
      register_id = id.to_sym
      context(register_id)

      model_register = Lutaml::Model::Register.new(register_id, fallback: fallback_to)
      resolve_substitutions(
        substitutions,
        registry: build_registry,
        fallback_to: fallback_to,
        id: "#{register_id}_register",
      ).each do |substitution|
        model_register.register_global_type_substitution(**substitution)
      end

      explicit_registers[register_id] = Lutaml::Model::GlobalRegister.register(model_register)
    end

    def find_context(id)
      Lutaml::Model::GlobalContext.context(id.to_sym)
    end

    def resolve_type(type_name, context: context_id)
      Lutaml::Model::GlobalContext.resolve_type(type_name, context.to_sym)
    end

    def context(id = context_id, force_populate: false)
      existing = find_context(id)
      return existing if existing && !force_populate && populated_for(id)

      populate_context(id: id)
    end

    def populate_context(id: context_id, fallback_to: [:default], substitutions: [])
      Lutaml::Model::GlobalContext.unregister_context(id) if find_context(id)

      opts = { registry: build_registry, fallback_to: fallback_to, id: id }
      context = Lutaml::Model::GlobalContext.create_context(
        substitutions: resolve_substitutions(substitutions, **opts),
        **opts,
      )
      populated_for(id, value: true)
      context
    end

    def resolve_substitutions(substitutions, registry:, fallback_to:, id:)
      resolution_context = Lutaml::Model::TypeContext.derived(
        id: "#{id}_substitution_resolution",
        registry: registry,
        fallback_to: fallback_to,
      )

      substitutions&.map do |substitution|
        from_key = substitution[:from_type] || substitution[:from]
        to_key = substitution[:to_type] || substitution[:to]

        {
          from_type: resolve_substitution_type(from_key, resolution_context),
          to_type: resolve_substitution_type(to_key, resolution_context),
        }
      end
    end

    def resolve_substitution_type(value, resolution_context)
      return value if value.is_a?(Class)

      Lutaml::Model::TypeResolver.resolve(value, resolution_context)
    end

    def build_registry
      registry = Lutaml::Model::TypeRegistry.new
      registered_models.each { |model_id, klass| registry.register(model_id, klass) }
      registry
    end

    def populated_for(context_id, value: false)
      @populated_for ||= {}
      @populated_for[context_id.to_sym] ||= value
    end

    def explicit_registers
      @explicit_registers ||= {}
    end
  end
end
