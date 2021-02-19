# frozen_string_literal: true

module MiniSql
  module Result
    # AM serializer support
    alias :read_attribute_for_serialization :send

    def to_h
      r = {}
      instance_variables.each do |f|
        r[f.to_s.delete_prefix('@').to_sym] = instance_variable_get(f)
      end
      r
    end

    def values
      instance_variables.map { |f| instance_variable_get(f) }
    end

    def ==(other_result)
      self.class.decorator == other_result.class.decorator &&
      self.instance_variables == other_result.instance_variables &&
      self.values == other_result.values
    end

    def eql?(other_result)
      self == other_result
    end
  end
end
