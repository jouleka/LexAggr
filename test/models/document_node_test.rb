require "test_helper"

class DocumentNodeTest < ActiveSupport::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    legislation = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
    @version = LegislationVersion.create!(legislation: legislation, version_uri: "/eli/reg/2016/679/en", language: "en", valid_from: Date.new(2018, 5, 25))
  end

  test "valid document node with required fields" do
    node = DocumentNode.new(legislation_version: @version, tree_path: "act_1.part_1", element_type: "part", eid: "part_1", position: 1, depth: 1)
    assert node.valid?
  end

  test "invalid without legislation_version" do
    node = DocumentNode.new(tree_path: "act_1", element_type: "act")
    assert_not node.valid?
  end

  test "descendants_of returns child nodes" do
    parent = DocumentNode.create!(legislation_version: @version, tree_path: "act_1.part_2", element_type: "part", position: 1, depth: 1)
    child = DocumentNode.create!(legislation_version: @version, tree_path: "act_1.part_2.art_5", element_type: "article", parent: parent, position: 1, depth: 2)
    grandchild = DocumentNode.create!(legislation_version: @version, tree_path: "act_1.part_2.art_5.para_1", element_type: "paragraph", parent: child, position: 1, depth: 3)
    results = DocumentNode.descendants_of("act_1.part_2")
    assert_includes results, child
    assert_includes results, grandchild
  end

  test "ancestors_of returns parent nodes" do
    parent = DocumentNode.create!(legislation_version: @version, tree_path: "act_1.part_2", element_type: "part", position: 1, depth: 1)
    DocumentNode.create!(legislation_version: @version, tree_path: "act_1.part_2.art_5", element_type: "article", parent: parent, position: 1, depth: 2)
    results = DocumentNode.ancestors_of("act_1.part_2.art_5")
    assert_includes results, parent
  end
end
