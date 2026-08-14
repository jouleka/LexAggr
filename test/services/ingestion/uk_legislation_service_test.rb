require "test_helper"

class Ingestion::UkLegislationServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::UkLegislationService.new
    @publication_log = File.read(Rails.root.join("test/fixtures/files/uk_publication_log.xml"))
    @sample_akn = File.read(Rails.root.join("test/fixtures/files/uk_sample_akn.xml"))
  end

  test "fetch_document_list parses Atom publication log" do
    stub_request(:get, /legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 200, body: @publication_log, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 2, results.length

    assert_equal "/ukpga/2026/5", results[0][:frbr_uri]
    assert_equal "Data Protection (Amendment) Act 2026", results[0][:title]
    assert_equal "act", results[0][:legislation_type]

    assert_equal "/uksi/2026/200", results[1][:frbr_uri]
    assert_equal "The Environmental Protection (Microplastics) Regulations 2026", results[1][:title]
    assert_equal "regulation", results[1][:legislation_type]
  end

  test "fetch_document_list filters by date" do
    stub_request(:get, /legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 200, body: @publication_log, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: Date.new(2026, 3, 20))
    assert_equal 1, results.length
    assert_equal "/ukpga/2026/5", results[0][:frbr_uri]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves AKN XML" do
    stub_request(:get, /legislation\.gov\.uk\/ukpga\/2026\/5\/data\.akn/)
      .to_return(status: 200, body: @sample_akn, headers: { "Content-Type" => "application/xml" })

    ref = { source_identifier: "ukpga/2026/5", frbr_uri: "/ukpga/2026/5" }
    result = @service.fetch_document(ref: ref)

    assert_equal "ukpga/2026/5", result[:source_identifier]
    assert_equal @sample_akn, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(@sample_akn), result[:content_hash]
  end

  test "fetch_document handles 404" do
    stub_request(:get, /legislation\.gov\.uk\/ukpga\/2026\/999\/data\.akn/)
      .to_return(status: 404)

    ref = { source_identifier: "ukpga/2026/999", frbr_uri: "/ukpga/2026/999" }
    result = @service.fetch_document(ref: ref)
    assert_empty result
  end

  test "document_type_to_legislation_type maps correctly" do
    assert_equal "act", @service.send(:document_type_to_legislation_type, "UnitedKingdomPublicGeneralAct")
    assert_equal "regulation", @service.send(:document_type_to_legislation_type, "UnitedKingdomStatutoryInstrument")
    assert_equal "decision", @service.send(:document_type_to_legislation_type, "UnitedKingdomMinisterialOrder")
    assert_equal "other", @service.send(:document_type_to_legislation_type, "UnknownType")
  end
end
