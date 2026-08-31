module DataSources
  module CadastreOpenData
    class ShpReader
      POLYGON_TYPES = [ 5, 15, 25 ].freeze

      include Enumerable

      def initialize(io)
        @io = io
      end

      def each
        return enum_for(:each) unless block_given?

        read_header
        while (record_header = @io.read(8))&.bytesize == 8
          content_length = record_header[4, 4].unpack1("N") * 2
          content = @io.read(content_length)
          raise ArgumentError, "Invalid SHP record" unless content&.bytesize == content_length

          yield parse_polygon(content)
        end
      end

      private

      def read_header
        header = @io.read(100)
        raise ArgumentError, "Invalid SHP header" unless header&.bytesize == 100
        raise ArgumentError, "Unsupported SHP file" unless header[0, 4].unpack1("N") == 9994
      end

      def parse_polygon(content)
        shape_type = content[0, 4].unpack1("V")
        return if shape_type.zero?
        raise ArgumentError, "Unsupported SHP geometry type #{shape_type}" unless POLYGON_TYPES.include?(shape_type)

        part_count = content[36, 4].unpack1("V")
        point_count = content[40, 4].unpack1("V")
        part_starts = content[44, part_count * 4].unpack("V#{part_count}")
        point_offset = 44 + (part_count * 4)
        points = point_count.times.map do |index|
          content[point_offset + (index * 16), 16].unpack("E2")
        end
        rings = part_starts.each_with_index.filter_map do |start, index|
          finish = part_starts[index + 1] || point_count
          ring = points[start...finish]
          ring if ring&.length.to_i >= 4
        end
        return if rings.empty?

        "MULTILINESTRING(#{rings.map { |ring| "(#{ring.map { |x, y| "#{x} #{y}" }.join(',')})" }.join(',')})"
      end
    end
  end
end
