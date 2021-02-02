# frozen_string_literal: true

module MiniSql
  class Serializer < Array
    MAX_CACHE_SIZE = 500

    def initialize(result)
      replace(result)
    end

    def self.marshallable(result)
      new(result)
    end

    def _dump(level)
      JSON.generate(serialize)
    end

    def self._load(dump)
      materialize(JSON.parse(dump))
    end

    private

    def serialize
      if length == 0
        {}
      else
        {
          "decorator" => first.class.decorator.to_s,
          "fields" => first.to_h.keys,
          "data" => map(&:values),
        }
      end
    end

    def self.materialize(wrapper)
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
