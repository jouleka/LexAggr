require "test_helper"

class Ingestion::EurlexRssServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::EurlexRssService.new
  end

  test "parse_feed extracts entries from RSS XML" do
    rss_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>EUR-Lex - OJ L series</title>
          <item>
            <title>Regulation (EU) 2026/100</title>
            <link>https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32026R0100</link>
            <pubDate>Mon, 10 Apr 2026 00:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, Ingestion::EurlexRssService::OJ_L_FEED)
      .to_return(status: 200, body: rss_xml)

    entries = @service.fetch_new_entries
    assert_equal 1, entries.length
    assert_includes entries.first[:title], "Regulation (EU) 2026/100"
    assert_equal "32026R0100", entries.first[:celex_number]
  end

  test "extracts celex from EUR-Lex URL" do
    celex = @service.send(:extract_celex_from_url, "https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679")
    assert_equal "32016R0679", celex
  end

  test "handles feed fetch errors gracefully" do
    stub_request(:get, Ingestion::EurlexRssService::OJ_L_FEED)
      .to_return(status: 500)

    entries = @service.fetch_new_entries
    assert_empty entries
  end
end
