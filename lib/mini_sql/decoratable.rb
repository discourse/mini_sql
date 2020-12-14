# frozen_string_literal: true

module MiniSql
  module Decoratable
    def decorated(mod)
      @decoratorated_classes ||= {}
      @decoratorated_classes[mod] ||=
        Class.new(self) do
          include(mod)
          instance_eval <<~RUBY
            def decorator
              #{mod}
            end
          RUBY
        end
    end

    def decorator
      nil
    end
  end
end
