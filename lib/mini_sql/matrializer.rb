# frozen_string_literal: true

module MiniSql
  class Matrializer < Array

    def self.build(fields, instance_eval_code = '')
      Class.new do
        attr_accessor(*fields)

        # AM serializer support
        alias :read_attribute_for_serialization :send

        def to_h
          r = {}
          instance_variables.each do |f|
            r[f.to_s.sub('@', '').to_sym] = instance_variable_get(f)
          end
          r
        end

        instance_eval(instance_eval_code)
      end
    end

  end
end
