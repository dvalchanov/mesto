module DataSources
  module Nag
    class AdministrativeActImporter
      def self.call(record)
        new(record).call
      end

      def initialize(record)
        @record = record.deep_stringify_keys
      end

      def call
        attributes = @record.slice(
          "act_number", "title", "status", "issued_on", "effective_on", "issuer", "district", "locality",
          "upi", "address", "object_description", "construction_category", "built_up_area", "gross_floor_area",
          "source_url", "document_url", "properties"
        )
        attributes["geometry"] = point
        attributes["properties"] = attributes.fetch("properties", {}).to_h.merge(location_provenance).compact
        act = AdministrativeAct.find_or_initialize_by(
          registry_kind: @record.fetch("registry_kind"),
          external_key: @record.fetch("external_key")
        )
        act.assign_attributes(attributes)
        act.save!

        document_identifiers = Array(@record["cadastral_identifiers"])
        references = document_identifiers.index_with { "document" }
        references[@record["matched_identifier"]] ||= "search_query" if @record["matched_identifier"].present?
        references.each do |identifier, match_basis|
          parsed = CadastralIdentifier.new(identifier)
          next unless parsed.valid?

          reference = act.administrative_act_references.find_or_initialize_by(cadastral_identifier: parsed.to_s)
          reference.reference_level = parsed.level.to_s
          reference.match_basis = "document" if match_basis == "document"
          reference.match_basis ||= match_basis
          reference.save!
        end
        act
      end

      private

      def point
        if @record["longitude"] && @record["latitude"]
          return RGeo::Geographic.spherical_factory(srid: 4326)
            .point(@record["longitude"].to_f, @record["latitude"].to_f)
        end

        property = explicitly_referenced_property
        return unless property&.geometry

        CadastralProperty.where(id: property.id).pick(Arel.sql("ST_PointOnSurface(geometry)"))
      end

      def explicitly_referenced_property
        identifiers = Array(@record["cadastral_identifiers"])
        CadastralProperty.where(cadastral_identifier: identifiers)
          .order(Arel.sql("length(cadastral_identifier) DESC"))
          .first
      end

      def location_provenance
        if @record["longitude"] && @record["latitude"]
          { "location_basis" => "nag_supplied_point" }
        elsif (property = explicitly_referenced_property)&.geometry
          {
            "location_basis" => "cadastral_reference_representative_point",
            "location_reference" => property.cadastral_identifier
          }
        else
          { "location_basis" => "unavailable" }
        end
      end
    end
  end
end
