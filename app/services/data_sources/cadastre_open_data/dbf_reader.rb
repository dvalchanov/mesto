module DataSources
  module CadastreOpenData
    class DbfReader
      Field = Data.define(:name, :type, :length, :decimal_count)

      include Enumerable

      def initialize(io, encoding: Encoding::UTF_8)
        @io = io
        @encoding = encoding
      end

      def each
        return enum_for(:each) unless block_given?

        each_record { |record| yield record if record }
      end

      def each_record
        return enum_for(:each_record) unless block_given?

        record_count, header_length, record_length = read_header
        fields = read_fields(header_length)
        record_count.times do
          record = @io.read(record_length)
          break unless record&.bytesize == record_length

          yield(record.getbyte(0) == 0x2a ? nil : parse_record(record, fields))
        end
      end

      private

      def read_header
        header = @io.read(32)
        raise ArgumentError, "Invalid DBF header" unless header&.bytesize == 32

        [ header[4, 4].unpack1("V"), header[8, 2].unpack1("v"), header[10, 2].unpack1("v") ]
      end

      def read_fields(header_length)
        field_count = (header_length - 33) / 32
        fields = field_count.times.map do
          descriptor = @io.read(32)
          raise ArgumentError, "Invalid DBF field descriptor" unless descriptor&.bytesize == 32

          Field.new(
            name: descriptor[0, 11].delete("\0"), type: descriptor[11],
            length: descriptor.getbyte(16), decimal_count: descriptor.getbyte(17)
          )
        end
        terminator = @io.read(1)
        raise ArgumentError, "Invalid DBF header terminator" unless terminator&.getbyte(0) == 0x0d

        fields
      end

      def parse_record(record, fields)
        offset = 1
        fields.to_h do |field|
          raw_value = record[offset, field.length]
          offset += field.length
          [ field.name, decode(raw_value) ]
        end
      end

      def decode(value)
        value.to_s.delete("\0").strip.force_encoding(@encoding).scrub
      end
    end
  end
end
