require "rails_helper"

RSpec.describe "Copy style" do
  it "contains no en dash or em dash characters in application files" do
    forbidden_dashes = [ 0x2013, 0x2014 ].map { |codepoint| codepoint.chr(Encoding::UTF_8).b }
    paths = Dir["{app,config,content,db,lib,public,spec}/**/*"].select { |path| File.file?(path) }

    offenders = paths.select do |path|
      contents = File.binread(path)
      # Binary media (images, video) can contain these byte sequences by chance.
      next false if contents.include?("\x00".b)

      forbidden_dashes.any? { |dash| contents.include?(dash) }
    end

    expect(offenders).to be_empty, "Forbidden dash characters found in: #{offenders.join(', ')}"
  end
end
