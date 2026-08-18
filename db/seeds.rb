jurisdictions = [
  { code: "eu", name: "European Union", jurisdiction_type: "supranational", api_config: {
    sparql_endpoint: "https://publications.europa.eu/webapi/rdf/sparql",
    rss_feeds: [
      "https://eur-lex.europa.eu/content/help/search/predefined-rss.html"
    ]
  } },
  { code: "gb", name: "United Kingdom", jurisdiction_type: "country", api_config: {
    base_url: "https://www.legislation.gov.uk",
    publication_log: "https://www.legislation.gov.uk/update/data.feed",
    rate_limit: "3000 per 5 minutes"
  } },
  { code: "fi", name: "Finland", jurisdiction_type: "country", api_config: {
    base_url: "https://opendata.finlex.fi/finlex/avoindata/v1",
    swagger_url: "https://opendata.finlex.fi/swagger-ui/index.html"
  } },
  { code: "pl", name: "Poland", jurisdiction_type: "country", api_config: {
    base_url: "https://api.sejm.gov.pl/eli"
  } },
  { code: "es", name: "Spain", jurisdiction_type: "country", api_config: {
    base_url: "https://www.boe.es/datosabiertos/api/"
  } },
  { code: "it", name: "Italy", jurisdiction_type: "country", api_config: {
    base_url: "https://api.normattiva.it/t/normattiva.api/"
  } },
  { code: "fr", name: "France", jurisdiction_type: "country", api_config: {
    piste_url: "https://piste.gouv.fr/",
    bulk_xml_url: "https://echanges.dila.gouv.fr/OPENDATA/"
  } },
  { code: "ch", name: "Switzerland", jurisdiction_type: "country", api_config: {
    sparql_endpoint: "https://fedlex.data.admin.ch/sparqlendpoint"
  } },
  { code: "at", name: "Austria", jurisdiction_type: "country", api_config: {} },
  { code: "de", name: "Germany", jurisdiction_type: "country", api_config: {
    toc_url: "https://www.gesetze-im-internet.de/gii-toc.xml"
  } },
  { code: "nl", name: "Netherlands", jurisdiction_type: "country", api_config: {
    sru_endpoint: "http://zoekservice.overheid.nl/sru/Search"
  } },
  { code: "se", name: "Sweden", jurisdiction_type: "country", api_config: {
    base_url: "https://data.riksdagen.se/"
  } },
  { code: "dk", name: "Denmark", jurisdiction_type: "country", api_config: {
    base_url: "https://api.retsinformation.dk/",
    rate_limit: "1 per 10 seconds",
    operating_hours: "03:00-23:45"
  } },
  { code: "no", name: "Norway", jurisdiction_type: "country", api_config: {
    base_url: "https://api.lovdata.no/"
  } },
  { code: "pt", name: "Portugal", jurisdiction_type: "country", api_config: {
    eli_base: "http://data.dre.pt/eli/"
  } }
]

jurisdictions.each do |attrs|
  Jurisdiction.find_or_create_by!(code: attrs[:code]) do |j|
    j.name = attrs[:name]
    j.jurisdiction_type = attrs[:jurisdiction_type]
    j.api_config = attrs[:api_config]
  end
end

puts "Seeded #{Jurisdiction.count} jurisdictions"
