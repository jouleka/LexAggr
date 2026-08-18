require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "sanitizes imported legislation markup before rendering" do
    markup = <<~HTML
      <html><body>
        <p class="article" onclick="alert('xss')">Safe text</p>
        <a href="javascript:alert('xss')">unsafe link</a>
        <script>alert('xss')</script>
      </body></html>
    HTML

    rendered = extract_body_content(markup)

    assert_includes rendered, "Safe text"
    assert_includes rendered, 'class="article"'
    assert_not_includes rendered, "onclick"
    assert_not_includes rendered, "javascript:"
    assert_not_includes rendered, "<script"
  end

  test "keeps the supported legal-document structure" do
    markup = "<html><body><table><tr><td colspan=\"2\">Article 1</td></tr></table></body></html>"

    rendered = extract_body_content(markup)

    assert_includes rendered, "<table>"
    assert_includes rendered, 'colspan="2"'
    assert_includes rendered, "Article 1"
  end
end
