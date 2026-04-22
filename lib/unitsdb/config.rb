# frozen_string_literal: true

module Unitsdb
  class Config
    CONTEXT_ID = :unitsdb_v2

    class << self
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

      def models
        @models ||= {}
      end

      def models=(user_models)
        normalized_models = user_models.each_with_object({}) do |(id, klass), result|
          model_id = id.to_sym
          result[model_id] = register_model(klass, id: model_id)
        end

        models.merge!(normalized_models)
      end

      def model_for(model_name)
        model_id = model_name.to_sym
        models[model_id] || registered_models[model_id]
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
        return existing if existing && !force_populate && populated?(id)

        populate_context(id: id)
      end

      def populate_context(id: context_id, fallback_to: [:default], substitutions: [])
        Lutaml::Model::GlobalContext.unregister_context(id) if find_context(id)

        opts = { registry: build_registry, fallback_to: fallback_to, id: id }
        context = Lutaml::Model::GlobalContext.create_context(
          substitutions: resolve_substitutions(substitutions, **opts),
          **opts,
        )
        mark_populated!(id)
        context
      end

      def resolve_substitutions(substitutions, registry:, fallback_to:, id:)
        resolution_context = Lutaml::Model::TypeContext.derived(
          id: "#{id}_substitution_resolution",
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
        registered_models.each { |model_id, klass| registry.register(model_id, klass) }
        registry
      end

      def populated?(context_id)
        @populated_for&.[](context_id.to_sym)
      end

      def mark_populated!(context_id)
        @populated_for ||= {}
        @populated_for[context_id.to_sym] = true
      end

      def explicit_registers
        @explicit_registers ||= {}
      end
    end
  end
end
