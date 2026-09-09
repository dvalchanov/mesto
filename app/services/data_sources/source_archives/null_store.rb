module DataSources
  module SourceArchives
    class NullStore
      def enabled? = false
      def latest(...) = nil
      def candidate(...) = nil
      def stage_file(...) = nil
      def stage_json(...) = nil
      def promote(...) = nil
    end
  end
end
