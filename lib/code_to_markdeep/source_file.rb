# frozen_string_literal: true

require 'code_to_markdeep'

module CodeToMarkdeep
  class SourceFile < Struct.new(:name, :path, :lang, :included_by, :dst_name)
    include Comparable
    def initialize *args
      super
      name.freeze if name
      path.freeze if path
      included_by.freeze if included_by
    end
    def <=> other
      name <=> other.to_s
    end
    def to_s ; name ; end
    def copy_to! dst_dir
    end
  end
end

