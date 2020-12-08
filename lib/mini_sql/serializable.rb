# frozen_string_literal: true

module MiniSql
  class Serializable < Array
    def initialize(entries)
      replace(entries)
    end

    def marshal_dump
      [
        first.to_h.keys,
        map { |row| row.to_h.values },
        defined_decorator_module,
      ]
    end

    private def defined_decorator_module
      (first.class.included_modules - Class.new.included_modules).first
    end

    def marshal_load(args)
      fields, values_rows, decorator_module = args

      materializer = MiniSql::Materializer.build(fields)
      materializer.include(decorator_module) if decorator_module

      values_rows.each do |row_result|
        r = materializer.new
        fields.each_with_index do |f, col|
          r.instance_variable_set(:"@#{f}", row_result[col])
        end
        self << r
      end

      self
    end
  end
end
