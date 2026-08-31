module Cadastre
  class HierarchyMetricsBuilder
    def initialize(analysis:, properties:)
      @analysis = analysis
      @properties = properties
    end

    def call
      {}.merge(building_metrics).merge(object_metrics)
    end

    private

    def building_metrics
      building = @properties["building"]
      parcel = @properties["parcel"]
      return {} unless building && parcel && complete_archive?(building)

      buildings = related_records("building", @analysis.parcel_identifier)
      footprint = buildings.sum(:area_sqm)
      {
        "parcel_buildings_count" => buildings.count,
        "parcel_building_footprint_sqm" => footprint.to_f.round(2),
        "parcel_footprint_percent" => percentage(footprint, parcel.area_sqm)
      }.compact
    end

    def object_metrics
      object = @properties["individual_object"]
      building = @properties["building"]
      return {} unless object && building && complete_archive?(object)

      objects = related_records("individual_object", @analysis.building_identifier)
      actual_count = objects.count
      {
        "building_object_records_count" => actual_count,
        "building_declared_objects_count" => building.objects_count,
        "building_object_count_matches" => building.objects_count.present? && actual_count == building.objects_count,
        "building_object_areas_sum_sqm" => objects.sum(:area_sqm).to_f.round(2)
      }.compact
    end

    def related_records(level, parent_identifier)
      CadastralProperty.where(identifier_level: level)
        .where("cadastral_identifier LIKE ?", "#{parent_identifier}.%")
    end

    def complete_archive?(property)
      CadastreImport.where(
        source_archive_key: property.source_archive_key, status: "succeeded",
        importer_version: DataSources::CadastreOpenData::PropertyArchiveImporter::IMPORTER_VERSION
      ).exists?
    end

    def percentage(part, whole)
      return if whole.blank? || whole.zero?

      ((part / whole) * 100).round(2).to_f
    end
  end
end
