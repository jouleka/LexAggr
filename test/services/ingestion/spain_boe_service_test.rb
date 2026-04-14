require "test_helper"

class Ingestion::SpainBoeServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::SpainBoeService.new
    @sumario_response = File.read(Rails.root.join("test/fixtures/files/spain_sumario_response.xml"))
  end

  test "fetch_document_list parses sumario XML" do
    stub_request(:get, /boe\.es\/datosabiertos\/api\/boe\/sumario\/\d{8}/)
      .to_return(status: 200, body: @sumario_response, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: Date.current)
    assert_equal 2, results.length

    first = results[0]
    assert_equal "BOE-A-2026-5000", first[:source_identifier]
    assert_includes first[:title], "Ley 5/2026"
    assert_equal "act", first[:legislation_type]

    second = results[1]
    assert_equal "BOE-A-2026-5001", second[:source_identifier]
    assert_equal "regulation", second[:legislation_type]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /boe\.es\/datosabiertos\/api\/boe\/sumario\/\d{8}/)
      .to_return(status: 500)

    results = @service.fetch_document_list(since: Date.current)
    assert_empty results
  end

  test "fetch_document retrieves consolidated XML" do
    xml_body = "<documento><titulo>Ley 5/2026</titulo><texto>Articulo 1...</texto></documento>"
    stub_request(:get, "https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/BOE-A-2026-5000/texto")
      .to_return(status: 200, body: xml_body, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { source_identifier: "BOE-A-2026-5000" })
    assert_equal xml_body, result[:raw_xml]
    assert_equal Digest::SHA256.hexdigest(xml_body), result[:content_hash]
    assert_equal "BOE-A-2026-5000", result[:source_identifier]
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/BOE-A-9999-0000/texto")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { source_identifier: "BOE-A-9999-0000" })
    assert_empty result
  end

  test "detect_legislation_type from title" do
    assert_equal "act", @service.detect_legislation_type("Ley 5/2026, de 28 de marzo")
    assert_equal "regulation", @service.detect_legislation_type("Real Decreto 200/2026, por el que se regula")
    assert_equal "directive", @service.detect_legislation_type("Orden TDF/123/2026, por la que se establece")
    assert_equal "decision", @service.detect_legislation_type("Resolucion de 15 de marzo de 2026")
    assert_equal "other", @service.detect_legislation_type("Comunicacion oficial del gobierno")
  end
end
