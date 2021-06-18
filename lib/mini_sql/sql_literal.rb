# frozen_string_literal: true

module MiniSql
  class SqlLiteral
    def initialize(srt)
      @str = srt
    end

    def to_str
      @str
    end
  end

  def self.sql(string)
    SqlLiteral.new(string)
  end
end
