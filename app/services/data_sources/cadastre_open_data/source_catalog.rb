module DataSources
  module CadastreOpenData
    class SourceCatalog
      def initialize(profile: DataCoverage.profile)
        @profile = profile
      end

      def ensure_profile_entries!
        @profile.districts.flat_map { |district| ensure_district_entries!(district) }
      end

      def ensure_district_entries!(district)
        district = normalize_district(district)
        raise ArgumentError, "A valid Sofia district is required" unless district

        DistrictSynchronizer::ARCHIVE_NAMES.map do |object_kind, archive_name|
          archive_key = DistrictSynchronizer.archive_key(district, archive_name)
          CadastreSourceArchive.find_or_create_by!(
            source_archive_key: archive_key,
            coverage_profile_key: @profile.key
          ) do |entry|
            entry.assign_attributes(
              district:,
              object_kind: object_kind.to_s,
              source_url: source_url(archive_key),
              coverage_geometry: @profile.supporting_geometry,
              enabled: false,
              discovered_at: Time.current,
              permission_status: open_data_config.fetch("permission_status", "review_required"),
              attribution: open_data_config["attribution"],
              permission_reference: open_data_config["permission_reference"],
              metadata: {
                "download_scope" => "district_archive",
                "storage_reuse" => open_data_config["storage_reuse"],
                "redistribution" => open_data_config["redistribution"],
                "retention_constraints" => open_data_config["retention_constraints"],
                "rate_limit" => open_data_config["rate_limit"]
              }.compact
            )
          end
        end
      end

      private

      def source_url(archive_key)
        "#{open_data_config.fetch('download_url')}?#{URI.encode_www_form(path: archive_key)}"
      end

      def normalize_district(value)
        district = value.to_s.strip.sub(/\A(?:СО\s*[-\u2013]\s*)?(?:р-н|район)\s*/i, "")
        district if district.match?(/\A[\p{L}][\p{L}\s-]*\z/)
      end

      def open_data_config
        @open_data_config ||= DataSources.config.dig("cadastre", "open_data")
      end
    end
  end
end
