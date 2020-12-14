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
            "data" => result.map(&:to_h)
          }
        end

      JSON.generate(wrapper)
    end

    def self.from_json(json)
      wrapper = JSON.parse(json)
      if !wrapper["data"]
        []
      else
        materializer = cached_materializer(wrapper)
        wrapper["data"].map do |row|
          materializer.materialize(row)
        end
      end
    end

    def self.cached_materializer(wrapper)
      @cache ||= {}
      key = wrapper["data"][0].keys
      m = @cache.delete(key)
      if m
        @cache[key] = m
      else
        m = @cache[key] = materializer(wrapper)
        @cache.shift if @cache.length > MAX_CACHE_SIZE
      end

      if wrapper["decorator"] && wrapper["decorator"].length > 0
        decorator = Kernel.const_get(wrapper["decorator"])
        m = m.decorated(decorator)
      end

      m
    end

    def self.materializer(wrapper)
      fields = wrapper["data"][0].keys

      result = Class.new do
        extend MiniSql::Decoratable
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

        instance_eval <<~RUBY
          def materialize(hash)
            r = self.new
            #{fields.map { |f| "r.#{f} = hash['#{f}']" }.join("; ")}
            r
          end
        RUBY
      end

      result
    end
  end
end
