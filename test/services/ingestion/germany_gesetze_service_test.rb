require "test_helper"
require "zip"

class Ingestion::GermanyGesetzeServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::GermanyGesetzeService.new
    @toc_xml = File.read(Rails.root.join("test/fixtures/files/germany_toc.xml"))
    @norm_xml = File.read(Rails.root.join("test/fixtures/files/germany_norm_sample.xml"))
  end

  test "fetch_document_list parses TOC XML" do
    stub_request(:get, "https://www.gesetze-im-internet.de/gii-toc.xml")
      .to_return(status: 200, body: @toc_xml, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_equal 3, results.length

    first = results[0]
    assert_equal "gg", first[:source_identifier]
    assert_includes first[:title], "Grundgesetz"
    assert_equal "act", first[:legislation_type]
    assert_equal "/eli/de/gg", first[:frbr_uri]
    assert_equal "https://www.gesetze-im-internet.de/gg/xml.zip", first[:zip_url]

    second = results[1]
    assert_equal "bgb", second[:source_identifier]
    assert_includes second[:title], "Burgerliches Gesetzbuch"
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, "https://www.gesetze-im-internet.de/gii-toc.xml")
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document_list handles empty TOC" do
    empty_toc = '<?xml version="1.0" encoding="UTF-8"?><items></items>'
    stub_request(:get, "https://www.gesetze-im-internet.de/gii-toc.xml")
      .to_return(status: 200, body: empty_toc, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document downloads ZIP and extracts XML" do
    zip_data = build_test_zip("gg.xml", @norm_xml)

    stub_request(:get, "https://www.gesetze-im-internet.de/gg/xml.zip")
      .to_return(status: 200, body: zip_data, headers: { "Content-Type" => "application/zip" })

    result = @service.fetch_document(ref: {
      source_identifier: "gg",
      zip_url: "https://www.gesetze-im-internet.de/gg/xml.zip"
    })

    assert_equal @norm_xml, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@norm_xml), result[:content_hash]
    assert_equal "gg", result[:source_identifier]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://www.gesetze-im-internet.de/nonexistent/xml.zip")
      .to_return(status: 404)

    result = @service.fetch_document(ref: {
      source_identifier: "nonexistent",
      zip_url: "https://www.gesetze-im-internet.de/nonexistent/xml.zip"
    })
    assert_empty result
  end

  test "fetch_document handles blank zip_url" do
    result = @service.fetch_document(ref: { source_identifier: "test", zip_url: "" })
    assert_empty result
  end

  private

  def build_test_zip(filename, content)
    io = StringIO.new
    io.set_encoding("BINARY")
    Zip::OutputStream.write_buffer(io) do |zos|
      zos.put_next_entry(filename)
      zos.write(content)
    end
    io.string
  end
end
