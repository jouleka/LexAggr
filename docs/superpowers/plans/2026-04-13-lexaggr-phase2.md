# LexAggr Phase 2: Multi-Jurisdiction Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add UK, Finland, Poland, and Spain legislation ingestion services following the established strategy pattern, so LexAggr serves 5 jurisdictions.

**Architecture:** Each jurisdiction gets its own service class inheriting from `Ingestion::BaseService`, implementing `fetch_document_list(since:)` and `fetch_document(ref:)`. Services are registered in `IngestionServiceFactory`. The existing fan-out job pipeline (`JurisdictionSyncJob` -> `ParseLegislationDocumentJob`) handles all new jurisdictions without modification. UK and Finland return Akoma Ntoso XML (existing `AknParser` handles it). Poland returns JSON + HTML. Spain returns XML with a custom structure.

**Tech Stack:** Faraday (HTTP), Feedjira (Atom parsing for UK), Nokogiri (XML parsing), existing AknParser, webmock + mocha (testing)

---

## File Structure

```
app/
  services/
    ingestion/
      ingestion_service_factory.rb          # MODIFY: register 4 new services
      uk_legislation_service.rb             # CREATE: UK legislation.gov.uk
      finlex_service.rb                     # CREATE: Finland Finlex REST + AKN
      poland_eli_service.rb                 # CREATE: Poland Sejm ELI API
      spain_boe_service.rb                  # CREATE: Spain BOE API
  jobs/
    parse_legislation_document_job.rb       # MODIFY: add HTML content detection for Poland/Spain
config/
  recurring.yml                             # MODIFY: add schedules for 4 new jurisdictions
test/
  services/
    ingestion/
      uk_legislation_service_test.rb        # CREATE
      finlex_service_test.rb                # CREATE
      poland_eli_service_test.rb            # CREATE
      spain_boe_service_test.rb             # CREATE
  fixtures/
    files/
      uk_publication_log.xml                # CREATE: sample Atom feed
      uk_sample_akn.xml                     # CREATE: UK AKN document
      finlex_list_response.json             # CREATE: Finlex list
      finlex_sample_akn.xml                 # CREATE: Finnish AKN document
      poland_acts_response.json             # CREATE: Sejm acts list
      spain_sumario_response.xml            # CREATE: BOE sumario
      spain_legislation_response.xml        # CREATE: BOE consolidated text
```

---

## Task 1: UK Legislation Service

**Files:**
- Create: `app/services/ingestion/uk_legislation_service.rb`
- Create: `test/services/ingestion/uk_legislation_service_test.rb`
- Create: `test/fixtures/files/uk_publication_log.xml`
- Create: `test/fixtures/files/uk_sample_akn.xml`

- [ ] **Step 1: Create UK Atom feed fixture**

Create `test/fixtures/files/uk_publication_log.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:pbl="http://www.legislation.gov.uk/namespaces/publication-log"
      xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"
      xmlns:dc="http://purl.org/dc/elements/1.1/">
  <title>New Legislation - legislation.gov.uk</title>
  <updated>2026-04-01T10:00:00Z</updated>
  <entry>
    <id>http://www.legislation.gov.uk/id/ukpga/2026/5/2026-04-01T10:00:00Z</id>
    <title>Data Protection (Amendment) Act 2026</title>
    <updated>2026-04-01T10:00:00Z</updated>
    <published>2026-04-01T10:00:00Z</published>
    <dc:identifier>http://www.legislation.gov.uk/id/ukpga/2026/5</dc:identifier>
    <ukm:DocumentMainType Value="UnitedKingdomPublicGeneralAct"/>
    <ukm:Year Value="2026"/>
    <ukm:Number Value="5"/>
    <pbl:ContentType>legislation</pbl:ContentType>
    <pbl:Event>published</pbl:Event>
    <pbl:New>true</pbl:New>
    <pbl:Format>xml</pbl:Format>
    <link rel="alternate" type="application/xml" href="http://www.legislation.gov.uk/ukpga/2026/5/data.akn"/>
  </entry>
  <entry>
    <id>http://www.legislation.gov.uk/id/uksi/2026/200/2026-03-15T08:00:00Z</id>
    <title>The Environmental Protection (Microplastics) Regulations 2026</title>
    <updated>2026-03-15T08:00:00Z</updated>
    <published>2026-03-15T08:00:00Z</published>
    <dc:identifier>http://www.legislation.gov.uk/id/uksi/2026/200</dc:identifier>
    <ukm:DocumentMainType Value="UnitedKingdomStatutoryInstrument"/>
    <ukm:Year Value="2026"/>
    <ukm:Number Value="200"/>
    <pbl:ContentType>legislation</pbl:ContentType>
    <pbl:Event>published</pbl:Event>
    <pbl:New>true</pbl:New>
    <pbl:Format>xml</pbl:Format>
    <link rel="alternate" type="application/xml" href="http://www.legislation.gov.uk/uksi/2026/200/data.akn"/>
  </entry>
</feed>
```

- [ ] **Step 2: Create UK AKN document fixture**

Create `test/fixtures/files/uk_sample_akn.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<akomaNtoso xmlns="http://docs.oasis-open.org/legaldocml/ns/akn/3.0">
  <act name="act">
    <meta>
      <identification source="#source">
        <FRBRWork>
          <FRBRuri value="/ukpga/2026/5"/>
          <FRBRdate date="2026-04-01" name="enacted"/>
          <FRBRcountry value="gb"/>
        </FRBRWork>
        <FRBRExpression>
          <FRBRlanguage language="eng"/>
        </FRBRExpression>
      </identification>
    </meta>
    <preface>
      <longTitle>
        <p><docTitle>Data Protection (Amendment) Act 2026</docTitle></p>
      </longTitle>
    </preface>
    <body>
      <part eId="part_1">
        <num>Part 1</num>
        <heading>Preliminary</heading>
        <section eId="sec_1">
          <num>1</num>
          <heading>Overview</heading>
          <paragraph eId="sec_1__para_1">
            <num>(1)</num>
            <content>
              <p>This Act amends the Data Protection Act 2018.</p>
            </content>
          </paragraph>
        </section>
      </part>
    </body>
  </act>
</akomaNtoso>
```

- [ ] **Step 3: Write failing tests**

Create `test/services/ingestion/uk_legislation_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::UkLegislationServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::UkLegislationService.new
    @atom_feed = File.read(Rails.root.join("test/fixtures/files/uk_publication_log.xml"))
    @sample_akn = File.read(Rails.root.join("test/fixtures/files/uk_sample_akn.xml"))
  end

  test "fetch_document_list parses Atom publication log" do
    stub_request(:get, /www\.legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 200, body: @atom_feed, headers: { "Content-Type" => "application/atom+xml" })

    results = @service.fetch_document_list(since: 60.days.ago)
    assert_equal 2, results.length

    first = results[0]
    assert_equal "Data Protection (Amendment) Act 2026", first[:title]
    assert_equal "/ukpga/2026/5", first[:frbr_uri]
    assert_equal "act", first[:legislation_type]
    assert_equal "ukpga/2026/5", first[:source_identifier]
    assert_equal 2026, first[:year]
  end

  test "fetch_document_list filters by date" do
    stub_request(:get, /www\.legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 200, body: @atom_feed, headers: { "Content-Type" => "application/atom+xml" })

    results = @service.fetch_document_list(since: Date.new(2026, 3, 20))
    assert_equal 1, results.length
    assert_equal "Data Protection (Amendment) Act 2026", results[0][:title]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /www\.legislation\.gov\.uk\/update\/data\.feed/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves AKN XML" do
    stub_request(:get, "https://www.legislation.gov.uk/ukpga/2026/5/data.akn")
      .to_return(status: 200, body: @sample_akn, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { source_identifier: "ukpga/2026/5", frbr_uri: "/ukpga/2026/5" })
    assert_equal @sample_akn, result[:raw_xml]
    assert_equal "ukpga/2026/5", result[:source_identifier]
    assert result[:content_hash].present?
  end

  test "fetch_document handles 404" do
    stub_request(:get, "https://www.legislation.gov.uk/ukpga/2026/5/data.akn")
      .to_return(status: 404)

    result = @service.fetch_document(ref: { source_identifier: "ukpga/2026/5", frbr_uri: "/ukpga/2026/5" })
    assert_empty result
  end

  test "document_type_to_legislation_type maps correctly" do
    assert_equal "act", @service.send(:document_type_to_legislation_type, "UnitedKingdomPublicGeneralAct")
    assert_equal "act", @service.send(:document_type_to_legislation_type, "ScottishAct")
    assert_equal "regulation", @service.send(:document_type_to_legislation_type, "UnitedKingdomStatutoryInstrument")
    assert_equal "other", @service.send(:document_type_to_legislation_type, "UnknownType")
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/uk_legislation_service_test.rb
```

Expected: FAIL — `Ingestion::UkLegislationService` not defined.

- [ ] **Step 5: Implement UkLegislationService**

Create `app/services/ingestion/uk_legislation_service.rb`:

```ruby
module Ingestion
  class UkLegislationService < BaseService
    BASE_URL = "https://www.legislation.gov.uk".freeze
    PUBLICATION_LOG = "https://www.legislation.gov.uk/update/data.feed".freeze

    ATOM_NS = { "atom" => "http://www.w3.org/2005/Atom" }.freeze
    PBL_NS = "http://www.legislation.gov.uk/namespaces/publication-log".freeze
    UKM_NS = "http://www.legislation.gov.uk/namespaces/metadata".freeze
    DC_NS = "http://purl.org/dc/elements/1.1/".freeze

    DOC_TYPE_MAP = {
      "UnitedKingdomPublicGeneralAct" => "act",
      "UnitedKingdomLocalAct" => "act",
      "ScottishAct" => "act",
      "WelshParliamentAct" => "act",
      "NorthernIrelandAct" => "act",
      "UnitedKingdomStatutoryInstrument" => "regulation",
      "ScottishStatutoryInstrument" => "regulation",
      "WelshStatutoryInstrument" => "regulation",
      "NorthernIrelandStatutoryRule" => "regulation",
      "UnitedKingdomChurchInstrument" => "regulation",
      "UnitedKingdomMinisterialDirection" => "directive",
      "UnitedKingdomMinisterialOrder" => "decision"
    }.freeze

    def fetch_document_list(since:)
      response = uk_client.get("/update/data.feed", {
        event: "published",
        new: "true",
        format: "xml"
      })
      return [] unless response.status == 200

      parse_atom_feed(response.body, since: since.to_date)
    rescue Faraday::Error => e
      Rails.logger.error("[UkLegislationService] Publication log fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      source_id = ref[:source_identifier]
      url = "/#{source_id}/data.akn"
      response = uk_client.get(url)

      return {} unless response.status == 200

      {
        source_identifier: source_id,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[UkLegislationService] Document fetch failed for #{source_id}: #{e.message}")
      {}
    end

    private

    def uk_client
      @uk_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator; contact@lexaggr.eu)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_atom_feed(xml, since:)
      doc = Nokogiri::XML(xml) { |c| c.noblanks }
      ns = {
        "atom" => "http://www.w3.org/2005/Atom",
        "pbl" => PBL_NS,
        "ukm" => UKM_NS,
        "dc" => DC_NS
      }

      entries = doc.xpath("//atom:entry", ns)
      entries.filter_map do |entry|
        updated = entry.at_xpath("atom:updated", ns)&.text
        next unless updated
        entry_date = Date.parse(updated) rescue nil
        next if entry_date && entry_date < since

        content_type = entry.at_xpath("pbl:ContentType", ns)&.text
        next unless content_type == "legislation"

        dc_id = entry.at_xpath("dc:identifier", ns)&.text
        next unless dc_id

        # Extract path: "http://www.legislation.gov.uk/id/ukpga/2026/5" -> "ukpga/2026/5"
        source_id = dc_id.sub(%r{.*/id/}, "")
        doc_type = entry.at_xpath("ukm:DocumentMainType/@Value", ns)&.text
        year_val = entry.at_xpath("ukm:Year/@Value", ns)&.text&.to_i

        {
          title: entry.at_xpath("atom:title", ns)&.text&.strip,
          frbr_uri: "/#{source_id}",
          source_identifier: source_id,
          legislation_type: document_type_to_legislation_type(doc_type),
          date: updated,
          year: year_val
        }
      end
    end

    def document_type_to_legislation_type(doc_type)
      DOC_TYPE_MAP.fetch(doc_type, "other")
    end
  end
end
```

- [ ] **Step 6: Run tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/uk_legislation_service_test.rb
```

Expected: All 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/uk_legislation_service.rb test/services/ingestion/uk_legislation_service_test.rb test/fixtures/files/uk_publication_log.xml test/fixtures/files/uk_sample_akn.xml
git commit -m "feat: add UK legislation.gov.uk ingestion service with Atom feed parsing"
```

---

## Task 2: Finland Finlex Service

**Files:**
- Create: `app/services/ingestion/finlex_service.rb`
- Create: `test/services/ingestion/finlex_service_test.rb`
- Create: `test/fixtures/files/finlex_list_response.json`
- Create: `test/fixtures/files/finlex_sample_akn.xml`

- [ ] **Step 1: Create Finlex fixtures**

Create `test/fixtures/files/finlex_list_response.json`:

```json
[
  {
    "akn_uri": "/akn/fi/act/statute/2026/100/fin@",
    "status": "NEW"
  },
  {
    "akn_uri": "/akn/fi/act/statute/2026/101/fin@",
    "status": "NEW"
  },
  {
    "akn_uri": "/akn/fi/act/statute/2025/500/fin@",
    "status": "AMENDED"
  }
]
```

Create `test/fixtures/files/finlex_sample_akn.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<akomaNtoso xmlns="http://docs.oasis-open.org/legaldocml/ns/akn/3.0"
            xmlns:finlex="http://data.finlex.fi/schema/finlex">
  <act name="statute">
    <meta>
      <identification source="#finlex">
        <FRBRWork>
          <FRBRuri value="/akn/fi/act/statute/2026/100"/>
          <FRBRdate date="2026-03-15" name="enacted"/>
          <FRBRcountry value="fi"/>
        </FRBRWork>
        <FRBRExpression>
          <FRBRlanguage language="fin"/>
        </FRBRExpression>
      </identification>
    </meta>
    <preface>
      <longTitle>
        <p><docTitle>Laki henkilotietojen kasittelysta (100/2026)</docTitle></p>
      </longTitle>
    </preface>
    <body>
      <chapter eId="chp_1">
        <num>1 luku</num>
        <heading>Yleiset saannokset</heading>
        <section eId="sec_1">
          <num>1 &sect;</num>
          <heading>Lain tarkoitus</heading>
          <paragraph eId="sec_1__para_1">
            <content>
              <p>Taman lain tarkoituksena on suojata yksityisyytta.</p>
            </content>
          </paragraph>
        </section>
      </chapter>
    </body>
  </act>
</akomaNtoso>
```

- [ ] **Step 2: Write failing tests**

Create `test/services/ingestion/finlex_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::FinlexServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::FinlexService.new
    @list_response = File.read(Rails.root.join("test/fixtures/files/finlex_list_response.json"))
    @sample_akn = File.read(Rails.root.join("test/fixtures/files/finlex_sample_akn.xml"))
  end

  test "fetch_document_list parses JSON list" do
    stub_request(:get, /opendata\.finlex\.fi.*list/)
      .to_return(status: 200, body: @list_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: 60.days.ago)
    assert_equal 3, results.length

    first = results[0]
    assert_equal "/akn/fi/act/statute/2026/100", first[:frbr_uri]
    assert_equal "act", first[:legislation_type]
    assert_equal 2026, first[:year]
    assert_equal "100", first[:source_identifier]
  end

  test "fetch_document_list handles empty response" do
    stub_request(:get, /opendata\.finlex\.fi.*list/)
      .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /opendata\.finlex\.fi.*list/)
      .to_return(status: 500)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves AKN XML" do
    stub_request(:get, /opendata\.finlex\.fi.*2026\/100/)
      .to_return(status: 200, body: @sample_akn, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { frbr_uri: "/akn/fi/act/statute/2026/100", source_identifier: "100", year: 2026 })
    assert_equal @sample_akn, result[:raw_xml]
    assert result[:content_hash].present?
  end

  test "fetch_document handles 404" do
    stub_request(:get, /opendata\.finlex\.fi.*2026\/999/)
      .to_return(status: 404)

    result = @service.fetch_document(ref: { frbr_uri: "/akn/fi/act/statute/2026/999", source_identifier: "999", year: 2026 })
    assert_empty result
  end

  test "parse_akn_uri extracts year and number" do
    year, number = @service.send(:parse_akn_uri, "/akn/fi/act/statute/2026/100/fin@")
    assert_equal 2026, year
    assert_equal "100", number
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/finlex_service_test.rb
```

Expected: FAIL — class not defined.

- [ ] **Step 4: Implement FinlexService**

Create `app/services/ingestion/finlex_service.rb`:

```ruby
module Ingestion
  class FinlexService < BaseService
    BASE_URL = "https://opendata.finlex.fi".freeze
    API_PATH = "/finlex/avoindata/v1".freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      current_year = Date.current.year
      start_year = since_date.year

      all_results = []
      (start_year..current_year).each do |year|
        page = 1
        loop do
          response = finlex_client.get("#{API_PATH}/akn/fi/act/statute/list", {
            format: "json",
            page: page,
            limit: 100,
            sortBy: "dateIssued",
            startYear: year,
            endYear: year
          })

          break unless response.status == 200

          entries = JSON.parse(response.body)
          break if entries.empty?

          entries.each do |entry|
            year_val, number = parse_akn_uri(entry["akn_uri"])
            next unless year_val && number

            all_results << {
              frbr_uri: "/akn/fi/act/statute/#{year_val}/#{number}",
              title: "Finnish Statute #{number}/#{year_val}",
              source_identifier: number,
              legislation_type: "act",
              date: "#{year_val}-01-01",
              year: year_val
            }
          end

          break if entries.length < 100
          page += 1
        end
      end

      all_results
    rescue Faraday::Error => e
      Rails.logger.error("[FinlexService] List fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      year = ref[:year] || parse_akn_uri(ref[:frbr_uri])&.first
      number = ref[:source_identifier]
      return {} unless year && number

      response = finlex_client.get("#{API_PATH}/akn/fi/act/statute/#{year}/#{number}/fin@")
      return {} unless response.status == 200

      {
        source_identifier: number,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[FinlexService] Document fetch failed: #{e.message}")
      {}
    end

    private

    def finlex_client
      @finlex_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator; contact@lexaggr.eu)"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_akn_uri(uri)
      match = uri&.match(%r{/akn/fi/act/statute/(\d{4})/(\d+)})
      return nil unless match
      [match[1].to_i, match[2]]
    end
  end
end
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/finlex_service_test.rb
```

Expected: All 6 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/finlex_service.rb test/services/ingestion/finlex_service_test.rb test/fixtures/files/finlex_list_response.json test/fixtures/files/finlex_sample_akn.xml
git commit -m "feat: add Finland Finlex ingestion service with AKN XML support"
```

---

## Task 3: Poland Sejm ELI Service

**Files:**
- Create: `app/services/ingestion/poland_eli_service.rb`
- Create: `test/services/ingestion/poland_eli_service_test.rb`
- Create: `test/fixtures/files/poland_acts_response.json`

- [ ] **Step 1: Create Poland fixture**

Create `test/fixtures/files/poland_acts_response.json`:

```json
{
  "count": 3,
  "items": [
    {
      "ELI": "DU/2026/100",
      "publisher": "DU",
      "year": 2026,
      "pos": 100,
      "title": "Ustawa z dnia 15 marca 2026 r. o ochronie danych osobowych",
      "type": "Ustawa",
      "status": "obowiazujacy",
      "inForce": "IN_FORCE",
      "announcementDate": "2026-03-20",
      "promulgation": "2026-04-01",
      "changeDate": "2026-04-01T12:00:00",
      "textHTML": true,
      "textPDF": true
    },
    {
      "ELI": "DU/2026/101",
      "publisher": "DU",
      "year": 2026,
      "pos": 101,
      "title": "Rozporzadzenie Ministra Cyfryzacji z dnia 10 marca 2026 r.",
      "type": "Rozporzadzenie",
      "status": "obowiazujacy",
      "inForce": "IN_FORCE",
      "announcementDate": "2026-03-15",
      "promulgation": "2026-03-25",
      "changeDate": "2026-03-25T08:30:00",
      "textHTML": true,
      "textPDF": true
    },
    {
      "ELI": "DU/2026/50",
      "publisher": "DU",
      "year": 2026,
      "pos": 50,
      "title": "Ustawa z dnia 20 stycznia 2026 r. - Prawo energetyczne",
      "type": "Ustawa",
      "status": "uchylony",
      "inForce": "NOT_IN_FORCE",
      "announcementDate": "2026-01-25",
      "promulgation": "2026-02-01",
      "changeDate": "2026-03-01T10:00:00",
      "textHTML": true,
      "textPDF": false
    }
  ]
}
```

- [ ] **Step 2: Write failing tests**

Create `test/services/ingestion/poland_eli_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::PolandEliServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::PolandEliService.new
    @acts_response = File.read(Rails.root.join("test/fixtures/files/poland_acts_response.json"))
  end

  test "fetch_document_list parses JSON acts response" do
    stub_request(:get, /api\.sejm\.gov\.pl\/eli\/acts\/DU\/2026/)
      .to_return(status: 200, body: @acts_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    assert_equal 3, results.length

    first = results[0]
    assert_equal "/eli/pl/DU/2026/100", first[:frbr_uri]
    assert_equal "act", first[:legislation_type]
    assert_equal 2026, first[:year]
    assert_equal "in_force", first[:status]
    assert_includes first[:title], "ochronie danych"
  end

  test "fetch_document_list maps Polish status correctly" do
    stub_request(:get, /api\.sejm\.gov\.pl\/eli\/acts\/DU\/2026/)
      .to_return(status: 200, body: @acts_response, headers: { "Content-Type" => "application/json" })

    results = @service.fetch_document_list(since: Date.new(2026, 1, 1))
    repealed = results.find { |r| r[:frbr_uri].include?("50") }
    assert_equal "repealed", repealed[:status]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /api\.sejm\.gov\.pl/)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves HTML content" do
    sample_html = "<html><body><h1>Ustawa</h1><p>Article 1. This is the law.</p></body></html>"
    stub_request(:get, "https://api.sejm.gov.pl/eli/acts/DU/2026/100/text.html")
      .to_return(status: 200, body: sample_html, headers: { "Content-Type" => "text/html" })

    result = @service.fetch_document(ref: { publisher: "DU", year: 2026, pos: 100, frbr_uri: "/eli/pl/DU/2026/100" })
    assert_equal sample_html, result[:raw_xml]
    assert result[:content_hash].present?
  end

  test "fetch_document handles 404" do
    stub_request(:get, /api\.sejm\.gov\.pl.*text\.html/)
      .to_return(status: 404)

    result = @service.fetch_document(ref: { publisher: "DU", year: 2026, pos: 999, frbr_uri: "/eli/pl/DU/2026/999" })
    assert_empty result
  end

  test "polish_type_to_legislation_type maps correctly" do
    assert_equal "act", @service.send(:polish_type_to_legislation_type, "Ustawa")
    assert_equal "regulation", @service.send(:polish_type_to_legislation_type, "Rozporzadzenie")
    assert_equal "decision", @service.send(:polish_type_to_legislation_type, "Obwieszczenie")
    assert_equal "other", @service.send(:polish_type_to_legislation_type, "UnknownType")
  end
end
```

- [ ] **Step 3: Implement PolandEliService**

Create `app/services/ingestion/poland_eli_service.rb`:

```ruby
module Ingestion
  class PolandEliService < BaseService
    BASE_URL = "https://api.sejm.gov.pl/eli".freeze

    POLISH_TYPE_MAP = {
      "Ustawa" => "act",
      "Rozporzadzenie" => "regulation",
      "Rozporządzenie" => "regulation",
      "Obwieszczenie" => "decision",
      "Postanowienie" => "decision",
      "Zarządzenie" => "decision",
      "Uchwała" => "decision"
    }.freeze

    POLISH_STATUS_MAP = {
      "obowiazujacy" => "in_force",
      "obowiązujący" => "in_force",
      "uchylony" => "repealed",
      "akt jednorazowy" => "in_force",
      "wygaśnięcie aktu" => "repealed"
    }.freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      current_year = Date.current.year

      all_results = []
      (since_date.year..current_year).each do |year|
        response = poland_client.get("/eli/acts/DU/#{year}")
        next unless response.status == 200

        data = JSON.parse(response.body)
        items = data["items"] || []

        items.each do |item|
          change_date = item["changeDate"] ? DateTime.parse(item["changeDate"]) : nil
          next if change_date && change_date < since_date.to_datetime

          all_results << {
            frbr_uri: "/eli/pl/#{item["publisher"]}/#{item["year"]}/#{item["pos"]}",
            title: item["title"],
            source_identifier: item["ELI"],
            legislation_type: polish_type_to_legislation_type(item["type"]),
            status: polish_status_to_status(item["inForce"]),
            date: item["promulgation"] || item["announcementDate"],
            year: item["year"],
            publisher: item["publisher"],
            pos: item["pos"]
          }
        end
      end

      all_results
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("[PolandEliService] List fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      publisher = ref[:publisher] || "DU"
      year = ref[:year]
      pos = ref[:pos]
      return {} unless year && pos

      response = poland_client.get("/eli/acts/#{publisher}/#{year}/#{pos}/text.html")
      return {} unless response.status == 200

      {
        source_identifier: "#{publisher}/#{year}/#{pos}",
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[PolandEliService] Document fetch failed: #{e.message}")
      {}
    end

    private

    def poland_client
      @poland_client ||= Faraday.new(url: "https://api.sejm.gov.pl") do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator; contact@lexaggr.eu)"
        f.adapter Faraday.default_adapter
      end
    end

    def polish_type_to_legislation_type(polish_type)
      POLISH_TYPE_MAP.fetch(polish_type, "other")
    end

    def polish_status_to_status(in_force_field)
      case in_force_field
      when "IN_FORCE" then "in_force"
      when "NOT_IN_FORCE" then "repealed"
      else "pending"
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/poland_eli_service_test.rb
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/poland_eli_service.rb test/services/ingestion/poland_eli_service_test.rb test/fixtures/files/poland_acts_response.json
git commit -m "feat: add Poland Sejm ELI ingestion service with JSON API support"
```

---

## Task 4: Spain BOE Service

**Files:**
- Create: `app/services/ingestion/spain_boe_service.rb`
- Create: `test/services/ingestion/spain_boe_service_test.rb`
- Create: `test/fixtures/files/spain_sumario_response.xml`

- [ ] **Step 1: Create Spain fixture**

Create `test/fixtures/files/spain_sumario_response.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<response>
  <status>OK</status>
  <sumario>
    <diario>
      <numero>85</numero>
      <sumario_diario>
        <url_pdf>https://www.boe.es/boe/dias/2026/04/01/pdfs/BOE-S-2026-85.pdf</url_pdf>
      </sumario_diario>
      <seccion>
        <codigo>1</codigo>
        <nombre>I. Disposiciones generales</nombre>
        <departamento>
          <codigo>9540</codigo>
          <nombre>Jefatura del Estado</nombre>
          <item>
            <titulo>Ley 5/2026, de 28 de marzo, de proteccion de datos personales.</titulo>
            <identificador>BOE-A-2026-5000</identificador>
            <url_pdf>https://www.boe.es/boe/dias/2026/04/01/pdfs/BOE-A-2026-5000.pdf</url_pdf>
            <pagina_inicial>1</pagina_inicial>
            <pagina_final>25</pagina_final>
          </item>
          <item>
            <titulo>Real Decreto 200/2026, de 25 de marzo, por el que se regula la ciberseguridad.</titulo>
            <identificador>BOE-A-2026-5001</identificador>
            <url_pdf>https://www.boe.es/boe/dias/2026/04/01/pdfs/BOE-A-2026-5001.pdf</url_pdf>
            <pagina_inicial>26</pagina_inicial>
            <pagina_final>40</pagina_final>
          </item>
        </departamento>
      </seccion>
    </diario>
  </sumario>
</response>
```

- [ ] **Step 2: Write failing tests**

Create `test/services/ingestion/spain_boe_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::SpainBoeServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::SpainBoeService.new
    @sumario_response = File.read(Rails.root.join("test/fixtures/files/spain_sumario_response.xml"))
  end

  test "fetch_document_list parses sumario XML" do
    stub_request(:get, /www\.boe\.es\/datosabiertos\/api\/boe\/sumario/)
      .to_return(status: 200, body: @sumario_response, headers: { "Content-Type" => "application/xml" })

    results = @service.fetch_document_list(since: 1.day.ago)
    assert_equal 2, results.length

    first = results[0]
    assert_equal "BOE-A-2026-5000", first[:source_identifier]
    assert_includes first[:title], "proteccion de datos"
    assert_equal "/eli/es/BOE-A-2026-5000", first[:frbr_uri]
    assert_equal "act", first[:legislation_type]
  end

  test "fetch_document_list handles HTTP errors" do
    stub_request(:get, /www\.boe\.es/)
      .to_return(status: 500)

    results = @service.fetch_document_list(since: 1.day.ago)
    assert_empty results
  end

  test "fetch_document retrieves consolidated XML" do
    sample_xml = "<documento><titulo>Ley 5/2026</titulo><texto>Article 1. Content here.</texto></documento>"
    stub_request(:get, /www\.boe\.es\/datosabiertos\/api\/legislacion-consolidada\/id\/BOE-A-2026-5000\/texto/)
      .to_return(status: 200, body: sample_xml, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { source_identifier: "BOE-A-2026-5000", frbr_uri: "/eli/es/BOE-A-2026-5000" })
    assert_equal sample_xml, result[:raw_xml]
    assert result[:content_hash].present?
  end

  test "fetch_document handles 404" do
    stub_request(:get, /www\.boe\.es.*texto/)
      .to_return(status: 404)

    result = @service.fetch_document(ref: { source_identifier: "BOE-A-2026-9999", frbr_uri: "/eli/es/BOE-A-2026-9999" })
    assert_empty result
  end

  test "detect_legislation_type from title" do
    assert_equal "act", @service.send(:detect_legislation_type, "Ley 5/2026, de 28 de marzo")
    assert_equal "regulation", @service.send(:detect_legislation_type, "Real Decreto 200/2026")
    assert_equal "directive", @service.send(:detect_legislation_type, "Orden ministerial de 15 de marzo")
    assert_equal "other", @service.send(:detect_legislation_type, "Some random text")
  end
end
```

- [ ] **Step 3: Implement SpainBoeService**

Create `app/services/ingestion/spain_boe_service.rb`:

```ruby
module Ingestion
  class SpainBoeService < BaseService
    BASE_URL = "https://www.boe.es/datosabiertos/api".freeze

    def fetch_document_list(since:)
      since_date = since.to_date
      today = Date.current
      all_results = []

      # Poll daily summaries from since_date to today
      (since_date..today).each do |date|
        response = boe_client.get("/boe/sumario/#{date.strftime('%Y%m%d')}")
        next unless response.status == 200

        entries = parse_sumario(response.body, date)
        all_results.concat(entries)
      end

      all_results
    rescue Faraday::Error => e
      Rails.logger.error("[SpainBoeService] Sumario fetch failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      boe_id = ref[:source_identifier]
      return {} unless boe_id

      # Try consolidated text first, fall back to original
      response = boe_client.get("/legislacion-consolidada/id/#{boe_id}/texto")

      if response.status != 200
        # Fall back to PDF URL (store reference only)
        return {}
      end

      {
        source_identifier: boe_id,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[SpainBoeService] Document fetch failed for #{boe_id}: #{e.message}")
      {}
    end

    private

    def boe_client
      @boe_client ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 1.0, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator; contact@lexaggr.eu)"
        f.headers["Accept"] = "application/xml"
        f.adapter Faraday.default_adapter
      end
    end

    def parse_sumario(xml, date)
      doc = Nokogiri::XML(xml) { |c| c.noblanks }
      results = []

      doc.xpath("//item").each do |item|
        title = item.at_xpath("titulo")&.text&.strip
        identifier = item.at_xpath("identificador")&.text&.strip
        next unless title && identifier

        year = identifier.match(/(\d{4})/)[1].to_i rescue date.year

        results << {
          title: title,
          source_identifier: identifier,
          frbr_uri: "/eli/es/#{identifier}",
          legislation_type: detect_legislation_type(title),
          date: date.iso8601,
          year: year,
          status: "in_force"
        }
      end

      results
    end

    def detect_legislation_type(title)
      case title
      when /\bLey\b/i, /\bLey Org[aá]nica\b/i
        "act"
      when /\bReal Decreto\b/i, /\bReglamento\b/i
        "regulation"
      when /\bOrden\b/i, /\bDirectiva\b/i
        "directive"
      when /\bResoluci[oó]n\b/i, /\bDecisi[oó]n\b/i
        "decision"
      else
        "other"
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/spain_boe_service_test.rb
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/spain_boe_service.rb test/services/ingestion/spain_boe_service_test.rb test/fixtures/files/spain_sumario_response.xml
git commit -m "feat: add Spain BOE ingestion service with sumario XML parsing"
```

---

## Task 5: Register Services & Update Schedule

**Files:**
- Modify: `app/services/ingestion/ingestion_service_factory.rb`
- Modify: `config/recurring.yml`
- Modify: `test/services/ingestion/ingestion_service_factory_test.rb`
- Modify: `app/jobs/parse_legislation_document_job.rb`

- [ ] **Step 1: Update factory tests**

Add to `test/services/ingestion/ingestion_service_factory_test.rb`:

```ruby
  test "returns UkLegislationService for gb" do
    service = Ingestion::IngestionServiceFactory.for("gb")
    assert_kind_of Ingestion::UkLegislationService, service
  end

  test "returns FinlexService for fi" do
    service = Ingestion::IngestionServiceFactory.for("fi")
    assert_kind_of Ingestion::FinlexService, service
  end

  test "returns PolandEliService for pl" do
    service = Ingestion::IngestionServiceFactory.for("pl")
    assert_kind_of Ingestion::PolandEliService, service
  end

  test "returns SpainBoeService for es" do
    service = Ingestion::IngestionServiceFactory.for("es")
    assert_kind_of Ingestion::SpainBoeService, service
  end

  test "registered_codes includes all 5 jurisdictions" do
    codes = Ingestion::IngestionServiceFactory.registered_codes
    assert_includes codes, "eu"
    assert_includes codes, "gb"
    assert_includes codes, "fi"
    assert_includes codes, "pl"
    assert_includes codes, "es"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/ingestion_service_factory_test.rb
```

Expected: FAIL — new jurisdictions not registered.

- [ ] **Step 3: Update IngestionServiceFactory**

Update `app/services/ingestion/ingestion_service_factory.rb`:

```ruby
module Ingestion
  class IngestionServiceFactory
    STRATEGIES = {
      "eu" => "Ingestion::EurlexSparqlService",
      "gb" => "Ingestion::UkLegislationService",
      "fi" => "Ingestion::FinlexService",
      "pl" => "Ingestion::PolandEliService",
      "es" => "Ingestion::SpainBoeService"
    }.freeze

    def self.for(jurisdiction_code)
      class_name = STRATEGIES.fetch(jurisdiction_code)
      class_name.constantize.new
    end

    def self.registered?(jurisdiction_code)
      STRATEGIES.key?(jurisdiction_code)
    end

    def self.registered_codes
      STRATEGIES.keys
    end
  end
end
```

- [ ] **Step 4: Update ParseLegislationDocumentJob to handle HTML content**

The `detect_parser` method in `app/jobs/parse_legislation_document_job.rb` currently only recognizes AKN and Formex. Poland returns HTML and Spain returns custom XML. Update the `detect_parser` method to handle these gracefully (return nil so no document tree is built, but the raw content is still stored):

The existing code already returns `nil` for unrecognized formats, which skips tree building. No changes needed — verify this is the case by reading the file.

- [ ] **Step 5: Update recurring.yml**

Replace `config/recurring.yml`:

```yaml
production:
  eurlex_rss_sync:
    class: EurlexRssSyncJob
    schedule: "every 2 hours"
  eurlex_sparql_sync:
    class: JurisdictionSyncJob
    args: ["eu"]
    schedule: "every 6 hours"
  uk_sync:
    class: JurisdictionSyncJob
    args: ["gb"]
    schedule: "every 1 hour"
  finland_sync:
    class: JurisdictionSyncJob
    args: ["fi"]
    schedule: "every day at 3am"
  poland_sync:
    class: JurisdictionSyncJob
    args: ["pl"]
    schedule: "every day at 4am"
  spain_sync:
    class: JurisdictionSyncJob
    args: ["es"]
    schedule: "every day at 5am"

development:
  eurlex_rss_sync:
    class: EurlexRssSyncJob
    schedule: "every 2 hours"
  eurlex_sparql_sync:
    class: JurisdictionSyncJob
    args: ["eu"]
    schedule: "every 6 hours"
  uk_sync:
    class: JurisdictionSyncJob
    args: ["gb"]
    schedule: "every 1 hour"
  finland_sync:
    class: JurisdictionSyncJob
    args: ["fi"]
    schedule: "every day at 3am"
  poland_sync:
    class: JurisdictionSyncJob
    args: ["pl"]
    schedule: "every day at 4am"
  spain_sync:
    class: JurisdictionSyncJob
    args: ["es"]
    schedule: "every day at 5am"
```

- [ ] **Step 6: Run full test suite**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test
```

Expected: All tests PASS (existing + all new service tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/ingestion_service_factory.rb test/services/ingestion/ingestion_service_factory_test.rb config/recurring.yml
git commit -m "feat: register UK, Finland, Poland, Spain services and update recurring schedule"
```

---

## Task 6: Full Test Suite & Push

- [ ] **Step 1: Run complete test suite**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test
```

Expected: All tests PASS, zero failures.

- [ ] **Step 2: Push to GitHub**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git push origin main
```

- [ ] **Step 3: Test live ingestion for each jurisdiction**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr

# UK
bin/rails runner 'service = Ingestion::UkLegislationService.new; results = service.fetch_document_list(since: 30.days.ago); puts "UK: #{results.length} documents"'

# Finland
bin/rails runner 'service = Ingestion::FinlexService.new; results = service.fetch_document_list(since: 365.days.ago); puts "Finland: #{results.length} documents"'

# Poland
bin/rails runner 'service = Ingestion::PolandEliService.new; results = service.fetch_document_list(since: 365.days.ago); puts "Poland: #{results.length} documents"'

# Spain
bin/rails runner 'service = Ingestion::SpainBoeService.new; results = service.fetch_document_list(since: 1.day.ago); puts "Spain: #{results.length} documents"'
```

Report results for each jurisdiction.
