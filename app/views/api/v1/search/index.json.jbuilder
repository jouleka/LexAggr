json.meta do
  json.total @total
  json.page @page
  json.per_page @per_page
  json.query params[:q]
end

json.data @results do |legislation|
  json.id legislation.id
  json.frbr_uri legislation.frbr_uri
  json.celex_number legislation.celex_number
  json.title legislation.title
  json.legislation_type legislation.legislation_type
  json.year legislation.year
  json.status legislation.status
  json.jurisdiction do
    json.code legislation.jurisdiction.code
    json.name legislation.jurisdiction.name
  end
end

json.facets @facets
