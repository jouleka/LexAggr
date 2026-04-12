module Ingestion
  class EurlexRssService < BaseService
    OJ_L_FEED = "https://eur-lex.europa.eu/rss/ELX_3100.L.xml".freeze

    def fetch_new_entries
      response = http_client.get(OJ_L_FEED)
      return [] unless response.status == 200

      feed = Feedjira.parse(response.body)
      feed.entries.map do |entry|
        celex = extract_celex_from_url(entry.url)
        next unless celex
        {
          title: entry.title,
          celex_number: celex,
          url: entry.url,
          published_at: entry.published,
          frbr_uri: "/eli/celex/#{celex}"
        }
      end.compact
    rescue Faraday::Error, Feedjira::NoParserAvailable => e
      Rails.logger.error("[EurlexRssService] Feed fetch failed: #{e.message}")
      []
    end

    private

    def extract_celex_from_url(url)
      return nil unless url
      match = url.match(/CELEX:(\w+)/)
      match&.captures&.first
    end
  end
end
