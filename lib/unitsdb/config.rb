# frozen_string_literal: true

module Unitsdb
  class Config
    CONTEXT_ID = :unitsdb_v2

    class << self
      # The currently-active default context id. Config-populated
      # contexts are created on demand under this id.
      def context_id
        @context_id ||= CONTEXT_ID
      end

      # ---------------------------------------------------------------
      # Model registry
      # ---------------------------------------------------------------

      # Register a model class under `id`. Single registration API;
      # `models=` is a thin enumerator over this.
      def register_model(klass, id:)
        registered_models[id.to_sym] = klass
        klass
      end

      def registered_models
        @registered_models ||= {}
      end

      # Bulk-register models from a hash. Reads back through
      # `register_model` so there is a single source of truth.
      def models=(user_models)
        user_models.each do |id, klass|
          register_model(klass, id: id.to_sym)
        end
      end

      # Look up a registered model by id. Kept as a stable public
      # API for downstream gems (e.g. unitsml) that previously used
      # the Configuration module.
      def model_for(model_name)
        registered_models[model_name.to_sym]
      end

      # ---------------------------------------------------------------
      # Lutaml register bridge (opt-in)
      # ---------------------------------------------------------------

      # Look up the Lutaml::Model::Register id (or nil) that was
      # explicitly created for `context_id` via `populate_register`.
      def register_id_for(context_id = context_id())
        explicit_registers[context_id.to_sym]
      end

      # Create a Lutaml::Model::Register for `id`, enabling
      # `from_hash(register: id)` deserialization. Power-user API —
      # most callers want `populate_context` only.
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

      def explicit_registers
        @explicit_registers ||= {}
      end

      # ---------------------------------------------------------------
      # Context lifecycle
      # ---------------------------------------------------------------

      def find_context(id)
        Lutaml::Model::GlobalContext.context(id.to_sym)
      end

      def resolve_type(type_name, context: context_id)
        Lutaml::Model::GlobalContext.resolve_type(type_name, context.to_sym)
      end

      # Return the context for `id`, creating it via `populate_context`
      # when missing. Non-destructive: existing contexts (whether
      # Config-created or externally-managed) are returned as-is.
      # Use `populate_context` directly to force-rebuild.
      def context(id = context_id())
        find_context(id) || populate_context(id: id)
      end

      # Force-create a context under `id`, replacing any prior
      # context (owned or external).
      def populate_context(id: context_id, fallback_to: [:default],
                           substitutions: [])
        Lutaml::Model::GlobalContext.unregister_context(id) if find_context(id)

        opts = { registry: build_registry, fallback_to: fallback_to, id: id }
        Lutaml::Model::GlobalContext.create_context(
          substitutions: resolve_substitutions(substitutions, **opts),
          **opts,
        )
      end

      # Convenience: ensure the default context exists. Idempotent.
      # Used as the single bootstrap site for `Unitsdb.database` and
      # `Database.from_db`.
      def ensure_default_context!
        return if find_context(context_id)

        populate_context(id: context_id)
      end

      # ---------------------------------------------------------------
      # Substitution resolution
      # ---------------------------------------------------------------

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
        Unitsdb.eager_load_models!
        registry = Lutaml::Model::TypeRegistry.new
        registered_models.each { |model_id, klass| registry.register(model_id, klass) }
        registry
      end

      # ---------------------------------------------------------------
      # Test support — snapshot/restore/isolate
      # ---------------------------------------------------------------

      def capture_state
        {
          registered_models: registered_models.dup,
          explicit_registers: explicit_registers.dup,
          context_id: @context_id,
        }
      end

      def restore_state(snapshot)
        @registered_models = snapshot[:registered_models]
        @explicit_registers = snapshot[:explicit_registers]
        @context_id = snapshot[:context_id]
      end

      # Run a block against a fresh Lutaml global context, then
      # restore Config state so subsequent specs see bundled defaults.
      def with_isolated_config
        snapshot = capture_state
        Lutaml::Model::GlobalContext.reset!
        yield
      ensure
        restore_state(snapshot) if snapshot
        Lutaml::Model::GlobalContext.reset!
      end
    end
  end
end
