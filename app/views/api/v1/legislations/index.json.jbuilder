json.meta do
  json.total @total
  json.page @page
  json.per_page @per_page
  json.total_pages (@total.to_f / @per_page).ceil
end

json.data @legislations do |legislation|
  json.id legislation.id
  json.frbr_uri legislation.frbr_uri
  json.celex_number legislation.celex_number
  json.eli_uri legislation.eli_uri
  json.title legislation.title
  json.legislation_type legislation.legislation_type
  json.year legislation.year
  json.status legislation.status
  json.jurisdiction do
    json.code legislation.jurisdiction.code
    json.name legislation.jurisdiction.name
  end
  json.created_at legislation.created_at
  json.updated_at legislation.updated_at
end
