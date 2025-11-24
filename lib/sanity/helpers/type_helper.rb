# frozen_string_literal: true

module Sanity
  module TypeHelper
    def self.default_type(klass)
      return nil if klass == Sanity::Document

      type =
        if klass.respond_to?(:document_type) && klass.document_type
          klass.document_type.to_s
        else
          klass.to_s
        end

      type[0].downcase + type[1..]
    end
  end
end
