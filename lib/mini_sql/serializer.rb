# frozen_string_literal: true

module MiniSql
  module Serializer
    MAX_CACHE_SIZE = 500

    def self.to_json(result)
      wrapper =
        if result.length == 0
          {}
        else
          {
            "decorator" => result[0].class.decorator.to_s,
            "fields" => result[0].to_h.keys,
            "data" => result.map(&:values),
          }
        end

      JSON.generate(wrapper)
    end

    def self.from_json(json)
      wrapper = JSON.parse(json)
      if !wrapper["data"]
        []
      else
        materializer = cached_materializer(wrapper['fields'], wrapper['decorator'])
        wrapper["data"].map do |row|
          materializer.materialize(row)
        end
      end
    end

    def self.cached_materializer(fields, decorator_module = nil)
      @cache ||= {}
      key = fields
      m = @cache.delete(key)
      if m
        @cache[key] = m
      else
        m = @cache[key] = materializer(fields)
        @cache.shift if @cache.length > MAX_CACHE_SIZE
      end

      if decorator_module && decorator_module.length > 0
        decorator = Kernel.const_get(decorator_module)
        m = m.decorated(decorator)
      end

      m
    end

    def self.materializer(fields)
      Class.new do
        extend MiniSql::Decoratable
        include MiniSql::Result

        attr_accessor(*fields)

        instance_eval <<~RUBY
          def materialize(values)
            r = self.new
            #{col = -1; fields.map { |f| "r.#{f} = values[#{col += 1}]" }.join("; ")}
            r
          end
        RUBY
      end
    end
  end
end
