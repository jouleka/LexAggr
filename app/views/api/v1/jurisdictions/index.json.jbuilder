json.data @jurisdictions do |jurisdiction|
  json.code jurisdiction.code
  json.name jurisdiction.name
  json.jurisdiction_type jurisdiction.jurisdiction_type
  json.legislation_count jurisdiction.legislations.count
end
