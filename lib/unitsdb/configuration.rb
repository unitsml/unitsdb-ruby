# frozen_string_literal: true

module Unitsdb
  module Configuration
    extend self

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

    def context(id = context_id)
      context_id = id.to_sym
      current_context = Lutaml::Model::GlobalContext.context(context_id)
      return current_context if current_context

      populate_context(id: context_id)
    end

    def populate_context(id: context_id, fallback_to: [:default], substitutions: [])
      context_id = id.to_sym
      registry = build_registry

      existing_context = Lutaml::Model::GlobalContext.context(context_id)
      Lutaml::Model::GlobalContext.unregister_context(context_id) if existing_context
      resolved_substitutions = resolve_substitutions(
        substitutions,
        registry: registry,
        fallback_to: fallback_to,
        resolution_context_id: :"#{context_id}_substitution_resolution",
      )

      context = Lutaml::Model::GlobalContext.create_context(
        id: context_id,
        registry: registry,
        fallback_to: fallback_to,
        substitutions: resolved_substitutions,
      )
      context
    end

    def register(id: context_id, fallback: [:default])
      register_id = id.to_sym
      current_register = Lutaml::Model::GlobalRegister.lookup(register_id)
      return current_register if current_register

      populate_register(id: register_id, fallback: fallback)
    end

    def populate_register(id: context_id, fallback: [:default], substitutions: [])
      register_id = id.to_sym
      registry = build_registry
      existing_register = Lutaml::Model::GlobalRegister.lookup(register_id)
      Lutaml::Model::GlobalRegister.remove(register_id) if existing_register

      register = Lutaml::Model::Register.new(register_id, fallback: fallback)
      registered_models.each do |model_id, klass|
        register.register_model(klass, id: model_id)
      end
      resolve_substitutions(
        substitutions,
        registry: registry,
        fallback_to: fallback,
        resolution_context_id: :"#{register_id}_register_substitution_resolution",
      ).each do |substitution|
        register.register_global_type_substitution(**substitution)
      end

      Lutaml::Model::GlobalRegister.register(register)
      register
    end

    private

    def resolve_substitutions(substitutions, registry:, fallback_to:, resolution_context_id:)
      resolution_context = Lutaml::Model::TypeContext.derived(
        id: resolution_context_id,
        registry: registry,
        fallback_to: fallback_to,
      )

      Array(substitutions).map do |substitution|
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
      registered_models.each do |model_id, klass|
        registry.register(model_id, klass)
      end
      registry
    end
  end
end
