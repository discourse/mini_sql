# frozen_string_literal: true

module MiniSql
  module Result
    # AM serializer support
    alias :read_attribute_for_serialization :send

    def to_h
      r = {}
      instance_variables.each do |f|
        r[f.to_s.delete('@').to_sym] = instance_variable_get(f)
      end
      r
    end

    def values
      instance_variables.map { |f| instance_variable_get(f) }
    end
  end
end
