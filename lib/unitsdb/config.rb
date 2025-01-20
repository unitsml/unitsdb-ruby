# frozen_string_literal: true

module Unitsdb
  class Config
    class << self
      def models
        @models ||= {}
      end

      def models=(user_models)
        models.merge!(user_models)
      end

      def model_for(model_name)
        models[model_name]
      end
    end
  end
end
