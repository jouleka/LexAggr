require "test_helper"

class ParseLegislationDocumentJobTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @doc_ref = {
      celex_number: "32016R0679",
      title: "GDPR",
      frbr_uri: "/eli/celex/32016R0679",
      legislation_type: "regulation",
      date: "2016-04-27"
    }
    @sample_xml = File.read(Rails.root.join("test/fixtures/files/sample_akn.xml"))
  end

  test "creates legislation and version from document reference" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({
      celex_number: "32016R0679",
      raw_xml: @sample_xml,
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    })

    assert_difference ["Legislation.count", "LegislationVersion.count"], 1 do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end

    legislation = Legislation.find_by(frbr_uri: "/eli/celex/32016R0679")
    assert_equal "GDPR", legislation.title
    assert_equal "regulation", legislation.legislation_type
    assert_equal "32016R0679", legislation.celex_number
  end

  test "skips document if content_hash unchanged" do
    Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/celex/32016R0679",
      title: "GDPR",
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    )

    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({
      celex_number: "32016R0679",
      raw_xml: @sample_xml,
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    })

    assert_no_difference "LegislationVersion.count" do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end
  end

  test "handles empty fetch result gracefully" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({})

    assert_nothing_raised do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end
  end
end
