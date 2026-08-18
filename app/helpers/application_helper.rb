module ApplicationHelper
  LEGISLATION_HTML_TAGS = %w[
    table thead tbody tr th td caption colgroup col
    p div span br hr h1 h2 h3 h4 h5 h6
    ul ol li dl dt dd
    a img em strong b i u sub sup
    blockquote pre code
  ].freeze

  LEGISLATION_HTML_ATTRIBUTES = %w[
    href src alt title class style width border cellspacing cellpadding
    colspan rowspan valign align
  ].freeze

  # Official data feeds are still untrusted input. Extract the body and apply
  # one allowlist here so future callers cannot accidentally render raw markup.
  def extract_body_content(xhtml)
    return "" if xhtml.blank?

    doc = Nokogiri::HTML(xhtml)
    body = doc.at_css("body")
    content = body ? body.inner_html : xhtml

    sanitize content, tags: LEGISLATION_HTML_TAGS, attributes: LEGISLATION_HTML_ATTRIBUTES
  end
end
