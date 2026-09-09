require "rails_helper"

RSpec.describe DataSources::CadastreOpenData::ArchiveClient do
  let(:download_url) { "https://kais.cadastre.bg/bg/OpenData/Download" }
  let(:config) do
    { "download_url" => download_url, "download_timeout" => 1, "max_archive_bytes" => 1.megabyte }
  end
  let(:archive_key) do
    "област София (столица)/община Столична/гр. София (68134) - район Студентски/поземлени имоти.zip"
  end

  it "streams response chunks to disk without reading a buffered response body" do
    chunks = [ "PK\x03\x04".b, "archive".b, "-contents".b ]
    request = Struct.new(:headers, :options).new({}, Faraday::RequestOptions.new)
    response = Struct.new(:status, :headers).new(
      200,
      Faraday::Utils::Headers.new("etag" => '"archive-v2"')
    )
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get) do |_url, &configure_request|
      configure_request.call(request)
      received_bytes = 0
      chunks.each do |chunk|
        received_bytes += chunk.bytesize
        request.options.on_data.call(chunk, received_bytes, nil)
      end
      response
    end

    downloaded_path = nil
    described_class.new(config:, connection:).download(archive_key) do |path, source_url, metadata|
      downloaded_path = path
      expect(File.binread(path)).to eq(chunks.join)
      expect(source_url).to start_with(download_url)
      expect(metadata).to include(
        etag: '"archive-v2"',
        not_modified: false,
        checksum: Digest::SHA256.hexdigest(chunks.join),
        byte_size: chunks.sum(&:bytesize)
      )
    end

    expect(File.exist?(downloaded_path)).to be(false)
  end

  it "preserves conditional requests without creating a downloadable body for a 304" do
    last_modified_at = Time.utc(2026, 9, 1, 10, 30)
    request = Struct.new(:headers, :options).new({}, Faraday::RequestOptions.new)
    response = Struct.new(:status, :headers).new(304, Faraday::Utils::Headers.new)
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get) do |_url, &configure_request|
      configure_request.call(request)
      response
    end

    described_class.new(config:, connection:).download(
      archive_key,
      etag: '"archive-v1"',
      last_modified_at:
    ) do |path, _source_url, metadata|
      expect(path).to be_nil
      expect(metadata).to include(not_modified: true)
    end

    expect(request.headers).to include(
      "If-None-Match" => '"archive-v1"',
      "If-Modified-Since" => last_modified_at.httpdate
    )
  end

  it "streams successfully through the configured Faraday Net::HTTP adapter" do
    archive_body = "PK\x03\x04adapter-response".b
    stub_request(:get, download_url).with(query: { "path" => archive_key }).to_return(
      status: 200,
      body: archive_body,
      headers: { "ETag" => '"adapter-v1"' }
    )

    described_class.new(config:).download(archive_key) do |path, _source_url, metadata|
      expect(File.binread(path)).to eq(archive_body)
      expect(metadata).to include(etag: '"adapter-v1"', not_modified: false)
    end
  end

  it "discards bytes from a failed attempt before retrying" do
    Tempfile.create([ "cadastre-retry", ".zip" ]) do |download_io|
      download_io.binmode
      download_io.write("partial response")
      download_state = {
        io: download_io,
        digest: Digest::SHA256.new.update("partial response"),
        byte_size: "partial response".bytesize
      }
      request = Struct.new(:context).new({ download_state: })
      env = Struct.new(:request).new(request)

      described_class.new(config:).send(:reset_partial_download, env:)

      expect(download_io.pos).to eq(0)
      expect(download_io.size).to eq(0)
      expect(download_state[:digest].hexdigest).to eq(Digest::SHA256.hexdigest(""))
      expect(download_state[:byte_size]).to eq(0)
    end
  end

  it "aborts a response that exceeds the configured maximum size" do
    request = Struct.new(:headers, :options).new({}, Faraday::RequestOptions.new)
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get) do |_url, &configure_request|
      configure_request.call(request)
      request.options.on_data.call("oversized", 9, nil)
    end

    expect {
      described_class.new(config: config.merge("max_archive_bytes" => 4), connection:).download(archive_key) { }
    }.to raise_error(DataSources::CadastreOpenData::ArchiveTooLarge)
  end

  it "classifies an unpublished official archive separately from a generic network failure" do
    stub_request(:get, download_url).with(query: { "path" => archive_key }).to_return(status: 500)

    expect { described_class.new(config:).download(archive_key) { } }
      .to raise_error(DataSources::CadastreOpenData::ArchiveUnavailable) do |error|
        expect(error.status).to eq(500)
        expect(error.message).to include("район Студентски")
      end
  end
end
