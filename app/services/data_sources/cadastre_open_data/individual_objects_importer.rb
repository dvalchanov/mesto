module DataSources
  module CadastreOpenData
    class IndividualObjectsImporter < PropertyArchiveImporter
      def initialize(**arguments)
        super(**arguments, archive_kind: :individual_objects)
      end
    end
  end
end
