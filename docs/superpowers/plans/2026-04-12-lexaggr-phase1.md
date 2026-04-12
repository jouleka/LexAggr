# LexAggr Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the foundation Rails 8 app with PostgreSQL schema, ingestion framework, EUR-Lex CELLAR integration, and minimal Hotwire UI.

**Architecture:** Monolith-first Rails 8 full-stack app. Strategy pattern for multi-jurisdiction ingestion, fan-out background jobs via Solid Queue, PostgreSQL ltree for hierarchical document structure, tsvector for full-text search.

**Tech Stack:** Ruby 3.4.5, Rails 8.0.5, PostgreSQL 14+, Solid Queue, Hotwire (Turbo + Stimulus), Nokogiri, Faraday, feedjira, sparql-client, pg_search

---

## File Structure

```
LexAggr/
  app/
    models/
      jurisdiction.rb
      legislation.rb
      legislation_version.rb
      document_node.rb
      ingestion_log.rb
    services/
      ingestion/
        base_service.rb
        ingestion_service_factory.rb
        eurlex_sparql_service.rb
        eurlex_rss_service.rb
      parsers/
        base_parser.rb
        akn_parser.rb
        formex_parser.rb
    jobs/
      jurisdiction_sync_job.rb
      parse_legislation_document_job.rb
      eurlex_rss_sync_job.rb
    controllers/
      dashboard_controller.rb
      legislations_controller.rb
      search_controller.rb
      admin/
        ingestion_logs_controller.rb
    views/
      dashboard/
        index.html.erb
      legislations/
        index.html.erb
        show.html.erb
      search/
        index.html.erb
      admin/
        ingestion_logs/
          index.html.erb
      layouts/
        application.html.erb
  config/
    recurring.yml
    routes.rb
  db/
    migrate/
      *_enable_extensions.rb
      *_create_jurisdictions.rb
      *_create_legislations.rb
      *_create_legislation_versions.rb
      *_create_document_nodes.rb
      *_create_ingestion_logs.rb
    seeds.rb
  test/
    models/
      jurisdiction_test.rb
      legislation_test.rb
      legislation_version_test.rb
      document_node_test.rb
      ingestion_log_test.rb
    services/
      ingestion/
        base_service_test.rb
        ingestion_service_factory_test.rb
        eurlex_sparql_service_test.rb
        eurlex_rss_service_test.rb
      parsers/
        akn_parser_test.rb
        formex_parser_test.rb
    jobs/
      jurisdiction_sync_job_test.rb
      parse_legislation_document_job_test.rb
    controllers/
      dashboard_controller_test.rb
      legislations_controller_test.rb
      search_controller_test.rb
    fixtures/
      files/
        sample_akn.xml
        sample_formex.xml
```

---

## Task 1: Project Scaffold & GitHub Setup

**Files:**
- Create: Rails 8 app in `/Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr/`
- Modify: `Gemfile`
- Create: GitHub repo `jouleka/LexAggr`

- [ ] **Step 1: Generate Rails 8 app inside existing directory**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
rails new . --database=postgresql --skip-docker --force
```

The `--force` is needed because the `docs/` directory already exists. Rails will not overwrite our spec/plan files.

- [ ] **Step 2: Add gem dependencies to Gemfile**

Add these gems after the existing gem declarations in `Gemfile`:

```ruby
# Legislation ingestion
gem "faraday"
gem "faraday-retry"
gem "feedjira"
gem "sparql-client"

# Search
gem "pg_search"

# Job monitoring
gem "mission_control-jobs"
```

- [ ] **Step 3: Bundle install**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bundle install
```

Expected: All gems install successfully.

- [ ] **Step 4: Create and migrate database**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:create
```

Expected: `Created database 'LexAggr_development'` and `Created database 'LexAggr_test'`

- [ ] **Step 5: Verify Rails boots**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails runner "puts Rails.version"
```

Expected: `8.0.5`

- [ ] **Step 6: Initialize git and push to GitHub**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git init
git add -A
git commit -m "feat: initial Rails 8 scaffold with PostgreSQL and ingestion gems"
gh repo create jouleka/LexAggr --public --source=. --push
```

Expected: Repo created at `https://github.com/jouleka/LexAggr`

---

## Task 2: PostgreSQL Extensions & Jurisdictions Table

**Files:**
- Create: `db/migrate/TIMESTAMP_enable_extensions.rb`
- Create: `db/migrate/TIMESTAMP_create_jurisdictions.rb`
- Create: `app/models/jurisdiction.rb`
- Create: `test/models/jurisdiction_test.rb`

- [ ] **Step 1: Write the failing test for Jurisdiction model**

Create `test/models/jurisdiction_test.rb`:

```ruby
require "test_helper"

class JurisdictionTest < ActiveSupport::TestCase
  test "valid jurisdiction with required fields" do
    jurisdiction = Jurisdiction.new(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    assert jurisdiction.valid?
  end

  test "invalid without code" do
    jurisdiction = Jurisdiction.new(name: "European Union", jurisdiction_type: "supranational")
    assert_not jurisdiction.valid?
    assert_includes jurisdiction.errors[:code], "can't be blank"
  end

  test "invalid without name" do
    jurisdiction = Jurisdiction.new(code: "eu", jurisdiction_type: "supranational")
    assert_not jurisdiction.valid?
    assert_includes jurisdiction.errors[:name], "can't be blank"
  end

  test "code must be unique" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    duplicate = Jurisdiction.new(code: "eu", name: "EU Copy", jurisdiction_type: "supranational")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "api_config defaults to empty hash" do
    jurisdiction = Jurisdiction.create!(code: "gb", name: "United Kingdom", jurisdiction_type: "country")
    assert_equal({}, jurisdiction.api_config)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/models/jurisdiction_test.rb
```

Expected: FAIL — table does not exist.

- [ ] **Step 3: Generate extensions migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration EnableExtensions
```

Edit the generated migration:

```ruby
class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension "ltree"
    enable_extension "pg_trgm"
  end
end
```

- [ ] **Step 4: Generate jurisdictions migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration CreateJurisdictions
```

Edit the generated migration:

```ruby
class CreateJurisdictions < ActiveRecord::Migration[8.0]
  def change
    create_table :jurisdictions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :jurisdiction_type
      t.jsonb :api_config, default: {}

      t.timestamps
    end

    add_index :jurisdictions, :code, unique: true
  end
end
```

- [ ] **Step 5: Create Jurisdiction model**

Create `app/models/jurisdiction.rb`:

```ruby
class Jurisdiction < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  has_many :legislations, dependent: :destroy
  has_many :ingestion_logs, dependent: :destroy
end
```

- [ ] **Step 6: Run migration and tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:migrate
bin/rails test test/models/jurisdiction_test.rb
```

Expected: All 5 tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/migrate/ app/models/jurisdiction.rb test/models/jurisdiction_test.rb db/schema.rb
git commit -m "feat: add jurisdictions table with ltree and pg_trgm extensions"
```

---

## Task 3: Legislations Table & Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_legislations.rb`
- Create: `app/models/legislation.rb`
- Create: `test/models/legislation_test.rb`

- [ ] **Step 1: Write the failing test for Legislation model**

Create `test/models/legislation_test.rb`:

```ruby
require "test_helper"

class LegislationTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "valid legislation with required fields" do
    legislation = Legislation.new(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "General Data Protection Regulation",
      legislation_type: "regulation",
      year: 2016,
      status: "in_force"
    )
    assert legislation.valid?
  end

  test "invalid without frbr_uri" do
    legislation = Legislation.new(jurisdiction: @jurisdiction, title: "Test")
    assert_not legislation.valid?
    assert_includes legislation.errors[:frbr_uri], "can't be blank"
  end

  test "frbr_uri must be unique" do
    Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR"
    )
    duplicate = Legislation.new(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR Copy"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:frbr_uri], "has already been taken"
  end

  test "invalid without title" do
    legislation = Legislation.new(jurisdiction: @jurisdiction, frbr_uri: "/test/1")
    assert_not legislation.valid?
    assert_includes legislation.errors[:title], "can't be blank"
  end

  test "belongs to jurisdiction" do
    legislation = Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR"
    )
    assert_equal @jurisdiction, legislation.jurisdiction
  end

  test "has many versions" do
    legislation = Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR"
    )
    assert_respond_to legislation, :legislation_versions
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/models/legislation_test.rb
```

Expected: FAIL — table does not exist.

- [ ] **Step 3: Generate legislations migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration CreateLegislations
```

Edit the generated migration:

```ruby
class CreateLegislations < ActiveRecord::Migration[8.0]
  def change
    create_table :legislations do |t|
      t.references :jurisdiction, null: false, foreign_key: true
      t.string :frbr_uri, null: false
      t.string :celex_number
      t.string :eli_uri
      t.string :title, null: false
      t.string :legislation_type
      t.integer :year
      t.string :status
      t.string :source_identifier
      t.string :content_hash
      t.tsvector :searchable

      t.timestamps
    end

    add_index :legislations, :frbr_uri, unique: true
    add_index :legislations, :celex_number
    add_index :legislations, :eli_uri
    add_index :legislations, :status
    add_index :legislations, :searchable, using: :gin
  end
end
```

- [ ] **Step 4: Create Legislation model**

Create `app/models/legislation.rb`:

```ruby
class Legislation < ApplicationRecord
  belongs_to :jurisdiction
  has_many :legislation_versions, dependent: :destroy

  validates :frbr_uri, presence: true, uniqueness: true
  validates :title, presence: true

  scope :in_force, -> { where(status: "in_force") }
  scope :by_type, ->(type) { where(legislation_type: type) }
  scope :by_year, ->(year) { where(year: year) }
end
```

- [ ] **Step 5: Run migration and tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:migrate
bin/rails test test/models/legislation_test.rb
```

Expected: All 6 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/migrate/ app/models/legislation.rb test/models/legislation_test.rb db/schema.rb
git commit -m "feat: add legislations table with tsvector search and FRBR URI deduplication"
```

---

## Task 4: Legislation Versions Table & Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_legislation_versions.rb`
- Create: `app/models/legislation_version.rb`
- Create: `test/models/legislation_version_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/legislation_version_test.rb`:

```ruby
require "test_helper"

class LegislationVersionTest < ActiveSupport::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR"
    )
  end

  test "valid version with required fields" do
    version = LegislationVersion.new(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en",
      language: "en",
      valid_from: Date.new(2018, 5, 25),
      version_type: "original"
    )
    assert version.valid?
  end

  test "invalid without version_uri" do
    version = LegislationVersion.new(legislation: @legislation)
    assert_not version.valid?
    assert_includes version.errors[:version_uri], "can't be blank"
  end

  test "version_uri must be unique" do
    LegislationVersion.create!(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en",
      language: "en",
      valid_from: Date.new(2018, 5, 25)
    )
    duplicate = LegislationVersion.new(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en"
    )
    assert_not duplicate.valid?
  end

  test "in_force_on scope returns versions valid on a date" do
    LegislationVersion.create!(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en/v1",
      language: "en",
      valid_from: Date.new(2018, 5, 25),
      valid_to: Date.new(2020, 1, 1)
    )
    LegislationVersion.create!(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en/v2",
      language: "en",
      valid_from: Date.new(2020, 1, 2),
      valid_to: nil
    )

    results = LegislationVersion.in_force_on(Date.new(2019, 6, 1))
    assert_equal 1, results.count
    assert_equal "/eli/reg/2016/679/en/v1", results.first.version_uri
  end

  test "current scope returns versions with no valid_to" do
    LegislationVersion.create!(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en/v1",
      language: "en",
      valid_from: Date.new(2018, 5, 25),
      valid_to: Date.new(2020, 1, 1)
    )
    current = LegislationVersion.create!(
      legislation: @legislation,
      version_uri: "/eli/reg/2016/679/en/v2",
      language: "en",
      valid_from: Date.new(2020, 1, 2),
      valid_to: nil
    )

    results = LegislationVersion.current
    assert_includes results, current
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/models/legislation_version_test.rb
```

Expected: FAIL — table does not exist.

- [ ] **Step 3: Generate migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration CreateLegislationVersions
```

Edit the generated migration:

```ruby
class CreateLegislationVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :legislation_versions do |t|
      t.references :legislation, null: false, foreign_key: true
      t.string :version_uri, null: false
      t.string :language, default: "en"
      t.date :valid_from
      t.date :valid_to
      t.date :publication_date
      t.string :version_type
      t.text :raw_xml
      t.text :raw_html

      t.timestamps
    end

    add_index :legislation_versions, :version_uri, unique: true
    add_index :legislation_versions, [:valid_from, :valid_to]
  end
end
```

- [ ] **Step 4: Create model**

Create `app/models/legislation_version.rb`:

```ruby
class LegislationVersion < ApplicationRecord
  belongs_to :legislation
  has_many :document_nodes, dependent: :destroy

  validates :version_uri, presence: true, uniqueness: true

  scope :in_force_on, ->(date) {
    where("valid_from <= ? AND (valid_to IS NULL OR valid_to >= ?)", date, date)
  }
  scope :current, -> { where(valid_to: nil) }
  scope :in_language, ->(lang) { where(language: lang) }
end
```

- [ ] **Step 5: Run migration and tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:migrate
bin/rails test test/models/legislation_version_test.rb
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/migrate/ app/models/legislation_version.rb test/models/legislation_version_test.rb db/schema.rb
git commit -m "feat: add legislation_versions table with temporal scopes"
```

---

## Task 5: Document Nodes Table with ltree

**Files:**
- Create: `db/migrate/TIMESTAMP_create_document_nodes.rb`
- Create: `app/models/document_node.rb`
- Create: `test/models/document_node_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/document_node_test.rb`:

```ruby
require "test_helper"

class DocumentNodeTest < ActiveSupport::TestCase
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    legislation = Legislation.create!(jurisdiction: jurisdiction, frbr_uri: "/eli/reg/2016/679", title: "GDPR")
    @version = LegislationVersion.create!(
      legislation: legislation,
      version_uri: "/eli/reg/2016/679/en",
      language: "en",
      valid_from: Date.new(2018, 5, 25)
    )
  end

  test "valid document node with required fields" do
    node = DocumentNode.new(
      legislation_version: @version,
      tree_path: "act_1.part_1",
      element_type: "part",
      eid: "part_1",
      position: 1,
      depth: 1
    )
    assert node.valid?
  end

  test "invalid without legislation_version" do
    node = DocumentNode.new(tree_path: "act_1", element_type: "act")
    assert_not node.valid?
  end

  test "descendants_of returns child nodes" do
    parent = DocumentNode.create!(
      legislation_version: @version,
      tree_path: "act_1.part_2",
      element_type: "part",
      position: 1,
      depth: 1
    )
    child = DocumentNode.create!(
      legislation_version: @version,
      tree_path: "act_1.part_2.art_5",
      element_type: "article",
      parent: parent,
      position: 1,
      depth: 2
    )
    grandchild = DocumentNode.create!(
      legislation_version: @version,
      tree_path: "act_1.part_2.art_5.para_1",
      element_type: "paragraph",
      parent: child,
      position: 1,
      depth: 3
    )

    results = DocumentNode.descendants_of("act_1.part_2")
    assert_includes results, child
    assert_includes results, grandchild
  end

  test "ancestors_of returns parent nodes" do
    parent = DocumentNode.create!(
      legislation_version: @version,
      tree_path: "act_1.part_2",
      element_type: "part",
      position: 1,
      depth: 1
    )
    child = DocumentNode.create!(
      legislation_version: @version,
      tree_path: "act_1.part_2.art_5",
      element_type: "article",
      parent: parent,
      position: 1,
      depth: 2
    )

    results = DocumentNode.ancestors_of("act_1.part_2.art_5")
    assert_includes results, parent
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/models/document_node_test.rb
```

Expected: FAIL — table does not exist.

- [ ] **Step 3: Generate migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration CreateDocumentNodes
```

Edit the generated migration:

```ruby
class CreateDocumentNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :document_nodes do |t|
      t.references :legislation_version, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :document_nodes }
      t.column :tree_path, :ltree
      t.string :element_type
      t.string :eid
      t.string :num
      t.string :heading
      t.text :content_text
      t.integer :position
      t.integer :depth
      t.tsvector :searchable

      t.timestamps
    end

    add_index :document_nodes, :tree_path, using: :gist
    add_index :document_nodes, :searchable, using: :gin
    add_index :document_nodes, [:legislation_version_id, :eid]
  end
end
```

- [ ] **Step 4: Create model**

Create `app/models/document_node.rb`:

```ruby
class DocumentNode < ApplicationRecord
  belongs_to :legislation_version
  belongs_to :parent, class_name: "DocumentNode", optional: true
  has_many :children, class_name: "DocumentNode", foreign_key: :parent_id, dependent: :destroy

  scope :descendants_of, ->(path) {
    where("tree_path <@ ?::ltree", path.to_s)
  }
  scope :ancestors_of, ->(path) {
    where("tree_path @> ?::ltree", path.to_s)
  }
  scope :direct_children_of, ->(path) {
    where("tree_path ~ ?::lquery", "#{path}.*{1}")
  }
  scope :roots, -> { where(parent: nil) }

  HIERARCHICAL_TYPES = %w[part chapter title section article paragraph subparagraph clause point indent].freeze
end
```

- [ ] **Step 5: Run migration and tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:migrate
bin/rails test test/models/document_node_test.rb
```

Expected: All 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/migrate/ app/models/document_node.rb test/models/document_node_test.rb db/schema.rb
git commit -m "feat: add document_nodes table with ltree hierarchy"
```

---

## Task 6: Ingestion Logs Table & Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_ingestion_logs.rb`
- Create: `app/models/ingestion_log.rb`
- Create: `test/models/ingestion_log_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/ingestion_log_test.rb`:

```ruby
require "test_helper"

class IngestionLogTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "valid ingestion log" do
    log = IngestionLog.new(
      jurisdiction: @jurisdiction,
      source_name: "cellar_sparql",
      status: "running"
    )
    assert log.valid?
  end

  test "invalid without jurisdiction" do
    log = IngestionLog.new(source_name: "cellar_sparql", status: "running")
    assert_not log.valid?
  end

  test "latest_for scope returns most recent log per source" do
    IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed", created_at: 1.hour.ago)
    latest = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "completed")

    result = IngestionLog.latest_for(@jurisdiction, "cellar_sparql")
    assert_equal latest, result
  end

  test "mark_completed! updates status and count" do
    log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running")
    log.mark_completed!(documents_processed: 42)
    log.reload

    assert_equal "completed", log.status
    assert_equal 42, log.documents_processed
  end

  test "mark_failed! updates status and error" do
    log = IngestionLog.create!(jurisdiction: @jurisdiction, source_name: "cellar_sparql", status: "running")
    log.mark_failed!("Connection timeout")
    log.reload

    assert_equal "failed", log.status
    assert_equal "Connection timeout", log.error_message
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/models/ingestion_log_test.rb
```

Expected: FAIL — table does not exist.

- [ ] **Step 3: Generate migration**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails generate migration CreateIngestionLogs
```

Edit the generated migration:

```ruby
class CreateIngestionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ingestion_logs do |t|
      t.references :jurisdiction, null: false, foreign_key: true
      t.string :source_name
      t.string :status
      t.integer :documents_processed, default: 0
      t.string :last_etag
      t.datetime :last_modified_at
      t.text :error_message

      t.timestamps
    end

    add_index :ingestion_logs, [:jurisdiction_id, :source_name, :created_at], name: "idx_ingestion_logs_lookup"
  end
end
```

- [ ] **Step 4: Create model**

Create `app/models/ingestion_log.rb`:

```ruby
class IngestionLog < ApplicationRecord
  belongs_to :jurisdiction

  validates :jurisdiction, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.latest_for(jurisdiction, source_name)
    where(jurisdiction: jurisdiction, source_name: source_name)
      .order(created_at: :desc)
      .first
  end

  def mark_completed!(documents_processed:)
    update!(status: "completed", documents_processed: documents_processed)
  end

  def mark_failed!(error_message)
    update!(status: "failed", error_message: error_message)
  end
end
```

- [ ] **Step 5: Run migration and tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:migrate
bin/rails test test/models/ingestion_log_test.rb
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/migrate/ app/models/ingestion_log.rb test/models/ingestion_log_test.rb db/schema.rb
git commit -m "feat: add ingestion_logs table for tracking sync status"
```

---

## Task 7: Seed Data — Jurisdiction Records

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Write seed data**

Replace contents of `db/seeds.rb`:

```ruby
jurisdictions = [
  { code: "eu", name: "European Union", jurisdiction_type: "supranational", api_config: {
    sparql_endpoint: "https://publications.europa.eu/webapi/rdf/sparql",
    rss_feeds: [
      "https://eur-lex.europa.eu/content/help/search/predefined-rss.html"
    ]
  }},
  { code: "gb", name: "United Kingdom", jurisdiction_type: "country", api_config: {
    base_url: "https://www.legislation.gov.uk",
    publication_log: "https://www.legislation.gov.uk/update/data.feed",
    rate_limit: "3000 per 5 minutes"
  }},
  { code: "fi", name: "Finland", jurisdiction_type: "country", api_config: {
    base_url: "https://opendata.finlex.fi/finlex/avoindata/v1",
    swagger_url: "https://opendata.finlex.fi/swagger-ui/index.html"
  }},
  { code: "pl", name: "Poland", jurisdiction_type: "country", api_config: {
    base_url: "https://api.sejm.gov.pl/eli"
  }},
  { code: "es", name: "Spain", jurisdiction_type: "country", api_config: {
    base_url: "https://www.boe.es/datosabiertos/api/"
  }},
  { code: "it", name: "Italy", jurisdiction_type: "country", api_config: {
    base_url: "https://api.normattiva.it/t/normattiva.api/"
  }},
  { code: "fr", name: "France", jurisdiction_type: "country", api_config: {
    piste_url: "https://piste.gouv.fr/",
    bulk_xml_url: "https://echanges.dila.gouv.fr/OPENDATA/"
  }},
  { code: "ch", name: "Switzerland", jurisdiction_type: "country", api_config: {
    sparql_endpoint: "https://fedlex.data.admin.ch/sparqlendpoint"
  }},
  { code: "at", name: "Austria", jurisdiction_type: "country", api_config: {} },
  { code: "de", name: "Germany", jurisdiction_type: "country", api_config: {
    toc_url: "https://www.gesetze-im-internet.de/gii-toc.xml"
  }},
  { code: "nl", name: "Netherlands", jurisdiction_type: "country", api_config: {
    sru_endpoint: "http://zoekservice.overheid.nl/sru/Search"
  }},
  { code: "se", name: "Sweden", jurisdiction_type: "country", api_config: {
    base_url: "https://data.riksdagen.se/"
  }},
  { code: "dk", name: "Denmark", jurisdiction_type: "country", api_config: {
    base_url: "https://api.retsinformation.dk/",
    rate_limit: "1 per 10 seconds",
    operating_hours: "03:00-23:45"
  }},
  { code: "no", name: "Norway", jurisdiction_type: "country", api_config: {
    base_url: "https://api.lovdata.no/"
  }},
  { code: "pt", name: "Portugal", jurisdiction_type: "country", api_config: {
    eli_base: "http://data.dre.pt/eli/"
  }}
]

jurisdictions.each do |attrs|
  Jurisdiction.find_or_create_by!(code: attrs[:code]) do |j|
    j.name = attrs[:name]
    j.jurisdiction_type = attrs[:jurisdiction_type]
    j.api_config = attrs[:api_config]
  end
end

puts "Seeded #{Jurisdiction.count} jurisdictions"
```

- [ ] **Step 2: Run seeds**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails db:seed
```

Expected: `Seeded 15 jurisdictions`

- [ ] **Step 3: Verify in console**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails runner "puts Jurisdiction.pluck(:code, :name).map { |c, n| \"#{c}: #{n}\" }.join(\"\\n\")"
```

Expected: All 15 jurisdictions listed.

- [ ] **Step 4: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add db/seeds.rb
git commit -m "feat: add seed data for 15 European jurisdictions"
```

---

## Task 8: Ingestion Framework — Base Service & Factory

**Files:**
- Create: `app/services/ingestion/base_service.rb`
- Create: `app/services/ingestion/ingestion_service_factory.rb`
- Create: `test/services/ingestion/base_service_test.rb`
- Create: `test/services/ingestion/ingestion_service_factory_test.rb`

- [ ] **Step 1: Write the failing test for BaseService**

Create `test/services/ingestion/base_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::BaseServiceTest < ActiveSupport::TestCase
  test "fetch_document_list raises NotImplementedError" do
    service = Ingestion::BaseService.new
    assert_raises(NotImplementedError) { service.fetch_document_list(since: 1.day.ago) }
  end

  test "fetch_document raises NotImplementedError" do
    service = Ingestion::BaseService.new
    assert_raises(NotImplementedError) { service.fetch_document(ref: "test") }
  end

  test "http_client returns a Faraday connection with retry" do
    service = Ingestion::BaseService.new
    client = service.send(:http_client)
    assert_kind_of Faraday::Connection, client
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/base_service_test.rb
```

Expected: FAIL — `Ingestion::BaseService` not defined.

- [ ] **Step 3: Implement BaseService**

Create `app/services/ingestion/base_service.rb`:

```ruby
module Ingestion
  class BaseService
    def fetch_document_list(since:)
      raise NotImplementedError, "#{self.class}#fetch_document_list not implemented"
    end

    def fetch_document(ref:)
      raise NotImplementedError, "#{self.class}#fetch_document not implemented"
    end

    private

    def http_client(base_url: nil)
      Faraday.new(url: base_url) do |f|
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  retry_statuses: [429, 500, 502, 503, 504]
        f.headers["User-Agent"] = "LexAggr/1.0 (legislation-aggregator)"
        f.adapter Faraday.default_adapter
      end
    end

    def compute_content_hash(content)
      Digest::SHA256.hexdigest(content.to_s)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/base_service_test.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Write the failing test for IngestionServiceFactory**

Create `test/services/ingestion/ingestion_service_factory_test.rb`:

```ruby
require "test_helper"

class Ingestion::IngestionServiceFactoryTest < ActiveSupport::TestCase
  test "returns EurlexSparqlService for eu" do
    service = Ingestion::IngestionServiceFactory.for("eu")
    assert_kind_of Ingestion::EurlexSparqlService, service
  end

  test "raises KeyError for unknown jurisdiction" do
    assert_raises(KeyError) { Ingestion::IngestionServiceFactory.for("xx") }
  end

  test "registered? returns true for known jurisdictions" do
    assert Ingestion::IngestionServiceFactory.registered?("eu")
  end

  test "registered? returns false for unknown jurisdictions" do
    assert_not Ingestion::IngestionServiceFactory.registered?("xx")
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/ingestion_service_factory_test.rb
```

Expected: FAIL — classes not defined.

- [ ] **Step 7: Create a stub EurlexSparqlService (minimal, to satisfy factory)**

Create `app/services/ingestion/eurlex_sparql_service.rb`:

```ruby
module Ingestion
  class EurlexSparqlService < BaseService
    SPARQL_ENDPOINT = "https://publications.europa.eu/webapi/rdf/sparql".freeze
    CDM_PREFIX = "PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>".freeze

    def fetch_document_list(since:)
      # Will be implemented in Task 9
      []
    end

    def fetch_document(ref:)
      # Will be implemented in Task 9
      {}
    end
  end
end
```

- [ ] **Step 8: Implement IngestionServiceFactory**

Create `app/services/ingestion/ingestion_service_factory.rb`:

```ruby
module Ingestion
  class IngestionServiceFactory
    STRATEGIES = {
      "eu" => "Ingestion::EurlexSparqlService"
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

- [ ] **Step 9: Run tests to verify they pass**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/
```

Expected: All 7 tests PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ test/services/
git commit -m "feat: add ingestion framework with base service, factory, and EUR-Lex stub"
```

---

## Task 9: EUR-Lex SPARQL Service

**Files:**
- Modify: `app/services/ingestion/eurlex_sparql_service.rb`
- Create: `test/services/ingestion/eurlex_sparql_service_test.rb`
- Create: `test/fixtures/files/sparql_response.json`

- [ ] **Step 1: Create test fixture for SPARQL response**

Create `test/fixtures/files/sparql_response.json`:

```json
{
  "results": {
    "bindings": [
      {
        "celex": { "type": "literal", "value": "32016R0679" },
        "title": { "type": "literal", "value": "Regulation (EU) 2016/679 of the European Parliament and of the Council" },
        "date": { "type": "literal", "value": "2016-04-27", "datatype": "http://www.w3.org/2001/XMLSchema#date" },
        "work": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/fake-uuid-1" },
        "restype": { "type": "uri", "value": "http://publications.europa.eu/resource/authority/resource-type/REG" }
      },
      {
        "celex": { "type": "literal", "value": "32024R1689" },
        "title": { "type": "literal", "value": "Regulation (EU) 2024/1689 of the European Parliament and of the Council" },
        "date": { "type": "literal", "value": "2024-06-13", "datatype": "http://www.w3.org/2001/XMLSchema#date" },
        "work": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/fake-uuid-2" },
        "restype": { "type": "uri", "value": "http://publications.europa.eu/resource/authority/resource-type/REG" }
      }
    ]
  }
}
```

- [ ] **Step 2: Write the failing test**

Create `test/services/ingestion/eurlex_sparql_service_test.rb`:

```ruby
require "test_helper"

class Ingestion::EurlexSparqlServiceTest < ActiveSupport::TestCase
  setup do
    @service = Ingestion::EurlexSparqlService.new
    @sparql_response = File.read(Rails.root.join("test/fixtures/files/sparql_response.json"))
  end

  test "fetch_document_list returns parsed document references" do
    stub_request(:any, Ingestion::EurlexSparqlService::SPARQL_ENDPOINT)
      .to_return(status: 200, body: @sparql_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)

    assert_equal 2, results.length
    assert_equal "32016R0679", results[0][:celex_number]
    assert_equal "32024R1689", results[1][:celex_number]
    assert_equal "regulation", results[0][:legislation_type]
  end

  test "fetch_document_list handles empty results" do
    empty_response = { "results" => { "bindings" => [] } }.to_json
    stub_request(:any, Ingestion::EurlexSparqlService::SPARQL_ENDPOINT)
      .to_return(status: 200, body: empty_response, headers: { "Content-Type" => "application/sparql-results+json" })

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document_list handles HTTP errors gracefully" do
    stub_request(:any, Ingestion::EurlexSparqlService::SPARQL_ENDPOINT)
      .to_return(status: 503)

    results = @service.fetch_document_list(since: 30.days.ago)
    assert_empty results
  end

  test "fetch_document retrieves XHTML content from CELLAR" do
    cellar_url = "https://eur-lex.europa.eu/legal-content/EN/TXT/XML/?uri=CELEX:32016R0679"
    sample_xml = '<akomaNtoso xmlns="http://docs.oasis-open.org/legaldocml/ns/akn/3.0"><act name="regulation"></act></akomaNtoso>'

    stub_request(:get, cellar_url)
      .to_return(status: 200, body: sample_xml, headers: { "Content-Type" => "application/xml" })

    result = @service.fetch_document(ref: { celex_number: "32016R0679" })

    assert_equal sample_xml, result[:raw_xml]
    assert_equal "32016R0679", result[:celex_number]
  end

  test "build_sparql_query includes date filter" do
    query = @service.send(:build_sparql_query, since: Date.new(2026, 1, 1), limit: 10)
    assert_includes query, "2026-01-01"
    assert_includes query, "LIMIT 10"
    assert_includes query, "cdm:work_has_resource-type"
  end

  test "resource_type_to_legislation_type maps correctly" do
    assert_equal "regulation", @service.send(:resource_type_to_legislation_type, "REG")
    assert_equal "directive", @service.send(:resource_type_to_legislation_type, "DIR")
    assert_equal "decision", @service.send(:resource_type_to_legislation_type, "DEC")
    assert_equal "other", @service.send(:resource_type_to_legislation_type, "UNKNOWN")
  end
end
```

- [ ] **Step 3: Add webmock to Gemfile for HTTP stubbing**

Add to `Gemfile` in the test group:

```ruby
group :test do
  gem "webmock"
end
```

Run:

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bundle install
```

Add to `test/test_helper.rb` after `require "rails/test_help"`:

```ruby
require "webmock/minitest"
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/eurlex_sparql_service_test.rb
```

Expected: FAIL — methods not implemented.

- [ ] **Step 5: Implement EurlexSparqlService**

Replace `app/services/ingestion/eurlex_sparql_service.rb`:

```ruby
module Ingestion
  class EurlexSparqlService < BaseService
    SPARQL_ENDPOINT = "https://publications.europa.eu/webapi/rdf/sparql".freeze
    CDM_PREFIX = "PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>".freeze
    CELLAR_XML_BASE = "https://eur-lex.europa.eu/legal-content/EN/TXT/XML/?uri=CELEX:".freeze

    RESOURCE_TYPE_MAP = {
      "REG" => "regulation",
      "DIR" => "directive",
      "DEC" => "decision",
      "DIRDEL" => "delegated_directive",
      "REGDEL" => "delegated_regulation",
      "REGIMPL" => "implementing_regulation"
    }.freeze

    def fetch_document_list(since:)
      query = build_sparql_query(since: since, limit: 100)
      response = http_client.get(SPARQL_ENDPOINT, { query: query }, {
        "Accept" => "application/sparql-results+json"
      })

      return [] unless response.status == 200

      parse_sparql_results(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("[EurlexSparqlService] SPARQL query failed: #{e.message}")
      []
    end

    def fetch_document(ref:)
      celex = ref[:celex_number]
      url = "#{CELLAR_XML_BASE}#{celex}"
      response = http_client.get(url)

      return {} unless response.status == 200

      {
        celex_number: celex,
        raw_xml: response.body,
        content_hash: compute_content_hash(response.body)
      }
    rescue Faraday::Error => e
      Rails.logger.error("[EurlexSparqlService] Document fetch failed for #{celex}: #{e.message}")
      {}
    end

    private

    def build_sparql_query(since:, limit: 100)
      <<~SPARQL
        #{CDM_PREFIX}
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

        SELECT DISTINCT ?celex ?title ?date ?work ?restype
        WHERE {
          ?work cdm:work_has_resource-type ?restype .
          FILTER(?restype IN (
            <http://publications.europa.eu/resource/authority/resource-type/REG>,
            <http://publications.europa.eu/resource/authority/resource-type/DIR>,
            <http://publications.europa.eu/resource/authority/resource-type/DEC>
          ))
          ?work cdm:resource_legal_id_celex ?celex .
          ?work cdm:work_date_document ?date .
          ?work cdm:work_has_expression ?expr .
          ?expr cdm:expression_uses_language
                <http://publications.europa.eu/resource/authority/language/ENG> .
          ?expr cdm:expression_title ?title .
          FILTER(?date >= "#{since.to_date.iso8601}"^^xsd:date)
        }
        ORDER BY DESC(?date)
        LIMIT #{limit}
      SPARQL
    end

    def parse_sparql_results(json_body)
      data = JSON.parse(json_body)
      bindings = data.dig("results", "bindings") || []

      bindings.map do |binding|
        restype_uri = binding.dig("restype", "value") || ""
        restype_code = restype_uri.split("/").last

        {
          celex_number: binding.dig("celex", "value"),
          title: binding.dig("title", "value"),
          date: binding.dig("date", "value"),
          cellar_uri: binding.dig("work", "value"),
          legislation_type: resource_type_to_legislation_type(restype_code),
          frbr_uri: "/eli/celex/#{binding.dig('celex', 'value')}"
        }
      end
    end

    def resource_type_to_legislation_type(code)
      RESOURCE_TYPE_MAP.fetch(code, "other")
    end
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/eurlex_sparql_service_test.rb
```

Expected: All 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/eurlex_sparql_service.rb test/services/ingestion/eurlex_sparql_service_test.rb test/fixtures/files/sparql_response.json Gemfile Gemfile.lock test/test_helper.rb
git commit -m "feat: implement EUR-Lex CELLAR SPARQL ingestion service"
```

---

## Task 10: XML Parsers — AKN & Formex

**Files:**
- Create: `app/services/parsers/base_parser.rb`
- Create: `app/services/parsers/akn_parser.rb`
- Create: `app/services/parsers/formex_parser.rb`
- Create: `test/services/parsers/akn_parser_test.rb`
- Create: `test/services/parsers/formex_parser_test.rb`
- Create: `test/fixtures/files/sample_akn.xml`
- Create: `test/fixtures/files/sample_formex.xml`

- [ ] **Step 1: Create XML test fixtures**

Create `test/fixtures/files/sample_akn.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<akomaNtoso xmlns="http://docs.oasis-open.org/legaldocml/ns/akn/3.0">
  <act name="regulation">
    <meta>
      <identification source="#source">
        <FRBRWork>
          <FRBRuri value="/eli/reg/2016/679"/>
          <FRBRdate date="2016-04-27" name="adoption"/>
          <FRBRcountry value="eu"/>
        </FRBRWork>
        <FRBRExpression>
          <FRBRlanguage language="eng"/>
        </FRBRExpression>
      </identification>
    </meta>
    <preface>
      <longTitle>
        <p><docTitle>Regulation (EU) 2016/679 - General Data Protection Regulation</docTitle></p>
      </longTitle>
    </preface>
    <body>
      <chapter eId="chp_1">
        <num>Chapter I</num>
        <heading>General provisions</heading>
        <article eId="art_1">
          <num>Article 1</num>
          <heading>Subject-matter and objectives</heading>
          <paragraph eId="art_1__para_1">
            <num>1.</num>
            <content>
              <p>This Regulation lays down rules relating to the protection of natural persons.</p>
            </content>
          </paragraph>
        </article>
      </chapter>
    </body>
  </act>
</akomaNtoso>
```

Create `test/fixtures/files/sample_formex.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CONSLEG.ACT>
  <TITLE>
    <TI>
      <P>Council Regulation (EC) No 1/2003</P>
    </TI>
  </TITLE>
  <CONS.ANNEX>
    <CONS.DOC>
      <BIB.INSTANCE>
        <DATE ISO="20030116">16 January 2003</DATE>
        <NO.CELEX>32003R0001</NO.CELEX>
      </BIB.INSTANCE>
      <ENACTING.TERMS>
        <DIVISION TYPE="CHAPTER" ID="chp_1">
          <TITLE>
            <TI><P>CHAPTER I</P></TI>
            <STI><P>PRINCIPLES</P></STI>
          </TITLE>
          <ARTICLE ID="art_1">
            <TI><P>Article 1</P></TI>
            <STI><P>Subject matter</P></STI>
            <PARAG ID="art_1_par_1">
              <ALINEA>
                <P>This Regulation establishes the rules.</P>
              </ALINEA>
            </PARAG>
          </ARTICLE>
        </DIVISION>
      </ENACTING.TERMS>
    </CONS.DOC>
  </CONS.ANNEX>
</CONSLEG.ACT>
```

- [ ] **Step 2: Write the failing test for AknParser**

Create `test/services/parsers/akn_parser_test.rb`:

```ruby
require "test_helper"

class Parsers::AknParserTest < ActiveSupport::TestCase
  setup do
    xml = File.read(Rails.root.join("test/fixtures/files/sample_akn.xml"))
    @parser = Parsers::AknParser.new(xml)
  end

  test "extracts metadata" do
    metadata = @parser.extract_metadata
    assert_equal "/eli/reg/2016/679", metadata[:frbr_uri]
    assert_equal "2016-04-27", metadata[:date]
    assert_equal "eu", metadata[:country]
    assert_equal "eng", metadata[:language]
  end

  test "extracts title" do
    metadata = @parser.extract_metadata
    assert_includes metadata[:title], "General Data Protection Regulation"
  end

  test "extracts body hierarchy" do
    nodes = @parser.extract_body_hierarchy
    assert_equal 1, nodes.length

    chapter = nodes.first
    assert_equal "chapter", chapter[:element_type]
    assert_equal "chp_1", chapter[:eid]
    assert_equal "General provisions", chapter[:heading]

    article = chapter[:children].first
    assert_equal "article", article[:element_type]
    assert_equal "art_1", article[:eid]

    paragraph = article[:children].first
    assert_equal "paragraph", paragraph[:element_type]
    assert_includes paragraph[:content], "protection of natural persons"
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/parsers/akn_parser_test.rb
```

Expected: FAIL — `Parsers::AknParser` not defined.

- [ ] **Step 4: Implement BaseParser and AknParser**

Create `app/services/parsers/base_parser.rb`:

```ruby
module Parsers
  class BaseParser
    def initialize(xml_string)
      @doc = Nokogiri::XML(xml_string) { |c| c.strict.noblanks }
    end

    def extract_metadata
      raise NotImplementedError
    end

    def extract_body_hierarchy
      raise NotImplementedError
    end

    private

    def text_at(xpath, namespaces = {})
      @doc.at_xpath(xpath, namespaces)&.text&.strip
    end
  end
end
```

Create `app/services/parsers/akn_parser.rb`:

```ruby
module Parsers
  class AknParser < BaseParser
    AKN_NS = { "akn" => "http://docs.oasis-open.org/legaldocml/ns/akn/3.0" }.freeze

    HIERARCHICAL = %w[part chapter title section article
                      paragraph subparagraph clause point indent].freeze

    def extract_metadata
      {
        frbr_uri: text_at("//akn:FRBRWork/akn:FRBRuri/@value", AKN_NS),
        title: text_at("//akn:preface/akn:longTitle//akn:docTitle", AKN_NS),
        date: text_at("//akn:FRBRWork/akn:FRBRdate/@date", AKN_NS),
        country: text_at("//akn:FRBRWork/akn:FRBRcountry/@value", AKN_NS),
        language: text_at("//akn:FRBRExpression/akn:FRBRlanguage/@language", AKN_NS)
      }
    end

    def extract_body_hierarchy
      body = @doc.at_xpath("//akn:body", AKN_NS)
      return [] unless body

      parse_children(body, [])
    end

    private

    def parse_children(node, path)
      node.children.select(&:element?).filter_map do |child|
        next unless HIERARCHICAL.include?(child.name)

        current_path = path + [child["eId"] || child.name]
        {
          element_type: child.name,
          eid: child["eId"],
          heading: child.at_xpath("akn:heading", AKN_NS)&.text&.strip,
          num: child.at_xpath("akn:num", AKN_NS)&.text&.strip,
          content: child.at_xpath("akn:content", AKN_NS)&.text&.strip,
          path: current_path.join("."),
          children: parse_children(child, current_path)
        }
      end
    end
  end
end
```

- [ ] **Step 5: Run AKN parser tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/parsers/akn_parser_test.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 6: Write failing test for FormexParser**

Create `test/services/parsers/formex_parser_test.rb`:

```ruby
require "test_helper"

class Parsers::FormexParserTest < ActiveSupport::TestCase
  setup do
    xml = File.read(Rails.root.join("test/fixtures/files/sample_formex.xml"))
    @parser = Parsers::FormexParser.new(xml)
  end

  test "extracts metadata" do
    metadata = @parser.extract_metadata
    assert_includes metadata[:title], "Council Regulation"
    assert_equal "32003R0001", metadata[:celex_number]
    assert_equal "20030116", metadata[:date]
  end

  test "extracts body hierarchy" do
    nodes = @parser.extract_body_hierarchy
    assert_equal 1, nodes.length

    chapter = nodes.first
    assert_equal "chapter", chapter[:element_type]
    assert_equal "chp_1", chapter[:eid]

    article = chapter[:children].first
    assert_equal "article", article[:element_type]
    assert_equal "art_1", article[:eid]
    assert_includes article[:heading], "Subject matter"
  end
end
```

- [ ] **Step 7: Implement FormexParser**

Create `app/services/parsers/formex_parser.rb`:

```ruby
module Parsers
  class FormexParser < BaseParser
    DIVISION_TYPE_MAP = {
      "CHAPTER" => "chapter",
      "SECTION" => "section",
      "PART" => "part",
      "TITLE" => "title"
    }.freeze

    def extract_metadata
      {
        title: text_at("//TITLE/TI/P"),
        celex_number: text_at("//NO.CELEX"),
        date: text_at("//DATE/@ISO")
      }
    end

    def extract_body_hierarchy
      enacting = @doc.at_xpath("//ENACTING.TERMS")
      return [] unless enacting

      parse_formex_children(enacting, [])
    end

    private

    def parse_formex_children(node, path)
      results = []

      node.children.select(&:element?).each do |child|
        case child.name
        when "DIVISION"
          results << parse_division(child, path)
        when "ARTICLE"
          results << parse_article(child, path)
        end
      end

      results.compact
    end

    def parse_division(node, path)
      div_type = DIVISION_TYPE_MAP.fetch(node["TYPE"], "division")
      eid = node["ID"]
      current_path = path + [eid || div_type]

      {
        element_type: div_type,
        eid: eid,
        heading: node.at_xpath("TITLE/STI/P")&.text&.strip,
        num: node.at_xpath("TITLE/TI/P")&.text&.strip,
        content: nil,
        path: current_path.join("."),
        children: parse_formex_children(node, current_path)
      }
    end

    def parse_article(node, path)
      eid = node["ID"]
      current_path = path + [eid || "article"]

      children = node.xpath("PARAG").map do |parag|
        para_id = parag["ID"]
        para_path = current_path + [para_id || "para"]
        {
          element_type: "paragraph",
          eid: para_id,
          heading: nil,
          num: nil,
          content: parag.at_xpath("ALINEA/P")&.text&.strip,
          path: para_path.join("."),
          children: []
        }
      end

      {
        element_type: "article",
        eid: eid,
        heading: node.at_xpath("STI/P")&.text&.strip,
        num: node.at_xpath("TI/P")&.text&.strip,
        content: nil,
        path: current_path.join("."),
        children: children
      }
    end
  end
end
```

- [ ] **Step 8: Run all parser tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/parsers/
```

Expected: All 5 tests PASS.

- [ ] **Step 9: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/parsers/ test/services/parsers/ test/fixtures/files/
git commit -m "feat: add AKN and Formex XML parsers with Nokogiri"
```

---

## Task 11: Background Jobs — Fan-Out Pattern

**Files:**
- Create: `app/jobs/jurisdiction_sync_job.rb`
- Create: `app/jobs/parse_legislation_document_job.rb`
- Create: `test/jobs/jurisdiction_sync_job_test.rb`
- Create: `test/jobs/parse_legislation_document_job_test.rb`

- [ ] **Step 1: Write failing test for JurisdictionSyncJob**

Create `test/jobs/jurisdiction_sync_job_test.rb`:

```ruby
require "test_helper"

class JurisdictionSyncJobTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
  end

  test "creates ingestion log and enqueues document jobs" do
    mock_results = [
      { celex_number: "32016R0679", title: "GDPR", frbr_uri: "/eli/celex/32016R0679", legislation_type: "regulation", date: "2016-04-27" }
    ]

    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document_list).returns(mock_results)

    assert_difference "IngestionLog.count", 1 do
      assert_enqueued_with(job: ParseLegislationDocumentJob) do
        JurisdictionSyncJob.perform_now("eu")
      end
    end

    log = IngestionLog.last
    assert_equal "completed", log.status
    assert_equal 1, log.documents_processed
  end

  test "marks log as failed on error" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document_list).raises(StandardError, "Connection failed")

    JurisdictionSyncJob.perform_now("eu")

    log = IngestionLog.last
    assert_equal "failed", log.status
    assert_includes log.error_message, "Connection failed"
  end

  test "skips unregistered jurisdictions" do
    assert_no_difference "IngestionLog.count" do
      JurisdictionSyncJob.perform_now("xx")
    end
  end
end
```

- [ ] **Step 2: Add mocha gem for stubbing**

Add to `Gemfile` test group:

```ruby
group :test do
  gem "webmock"
  gem "mocha"
end
```

Run:

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bundle install
```

Add to `test/test_helper.rb` after webmock require:

```ruby
require "mocha/minitest"
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/jobs/jurisdiction_sync_job_test.rb
```

Expected: FAIL — `JurisdictionSyncJob` not defined.

- [ ] **Step 4: Implement JurisdictionSyncJob**

Create `app/jobs/jurisdiction_sync_job.rb`:

```ruby
class JurisdictionSyncJob < ApplicationJob
  queue_as :ingestion

  def perform(jurisdiction_code)
    return unless Ingestion::IngestionServiceFactory.registered?(jurisdiction_code)

    jurisdiction = Jurisdiction.find_by!(code: jurisdiction_code)
    service = Ingestion::IngestionServiceFactory.for(jurisdiction_code)
    log = IngestionLog.create!(jurisdiction: jurisdiction, source_name: service.class.name.demodulize.underscore, status: "running")

    last_log = IngestionLog.where(jurisdiction: jurisdiction, status: "completed").order(created_at: :desc).where.not(id: log.id).first
    since = last_log&.created_at || 30.days.ago

    documents = service.fetch_document_list(since: since)

    documents.each do |doc_ref|
      ParseLegislationDocumentJob.perform_later(jurisdiction_code, doc_ref.to_json)
    end

    log.mark_completed!(documents_processed: documents.length)
  rescue StandardError => e
    log&.mark_failed!(e.message)
    Rails.logger.error("[JurisdictionSyncJob] #{jurisdiction_code} failed: #{e.message}")
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/jobs/jurisdiction_sync_job_test.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 6: Write failing test for ParseLegislationDocumentJob**

Create `test/jobs/parse_legislation_document_job_test.rb`:

```ruby
require "test_helper"

class ParseLegislationDocumentJobTest < ActiveSupport::TestCase
  setup do
    @jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @doc_ref = {
      celex_number: "32016R0679",
      title: "GDPR",
      frbr_uri: "/eli/celex/32016R0679",
      legislation_type: "regulation",
      date: "2016-04-27"
    }
    @sample_xml = File.read(Rails.root.join("test/fixtures/files/sample_akn.xml"))
  end

  test "creates legislation and version from document reference" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({
      celex_number: "32016R0679",
      raw_xml: @sample_xml,
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    })

    assert_difference ["Legislation.count", "LegislationVersion.count"], 1 do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end

    legislation = Legislation.find_by(frbr_uri: "/eli/celex/32016R0679")
    assert_equal "GDPR", legislation.title
    assert_equal "regulation", legislation.legislation_type
    assert_equal "32016R0679", legislation.celex_number
  end

  test "skips document if content_hash unchanged" do
    Legislation.create!(
      jurisdiction: @jurisdiction,
      frbr_uri: "/eli/celex/32016R0679",
      title: "GDPR",
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    )

    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({
      celex_number: "32016R0679",
      raw_xml: @sample_xml,
      content_hash: Digest::SHA256.hexdigest(@sample_xml)
    })

    assert_no_difference "LegislationVersion.count" do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end
  end

  test "handles empty fetch result gracefully" do
    Ingestion::EurlexSparqlService.any_instance.stubs(:fetch_document).returns({})

    assert_nothing_raised do
      ParseLegislationDocumentJob.perform_now("eu", @doc_ref.to_json)
    end
  end
end
```

- [ ] **Step 7: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/jobs/parse_legislation_document_job_test.rb
```

Expected: FAIL — `ParseLegislationDocumentJob` not defined.

- [ ] **Step 8: Implement ParseLegislationDocumentJob**

Create `app/jobs/parse_legislation_document_job.rb`:

```ruby
class ParseLegislationDocumentJob < ApplicationJob
  queue_as :ingestion

  def perform(jurisdiction_code, doc_ref_json)
    doc_ref = JSON.parse(doc_ref_json, symbolize_names: true)
    jurisdiction = Jurisdiction.find_by!(code: jurisdiction_code)
    service = Ingestion::IngestionServiceFactory.for(jurisdiction_code)

    result = service.fetch_document(ref: doc_ref)
    return if result.empty?

    legislation = Legislation.find_or_initialize_by(frbr_uri: doc_ref[:frbr_uri])
    legislation.assign_attributes(
      jurisdiction: jurisdiction,
      title: doc_ref[:title],
      legislation_type: doc_ref[:legislation_type],
      celex_number: result[:celex_number] || doc_ref[:celex_number],
      year: extract_year(doc_ref[:date]),
      status: "in_force",
      source_identifier: doc_ref[:celex_number]
    )

    return if legislation.persisted? && legislation.content_hash == result[:content_hash]

    legislation.content_hash = result[:content_hash]
    legislation.save!

    version = legislation.legislation_versions.find_or_initialize_by(
      version_uri: "#{doc_ref[:frbr_uri]}/en"
    )
    version.assign_attributes(
      language: "en",
      valid_from: parse_date(doc_ref[:date]),
      version_type: "original",
      raw_xml: result[:raw_xml]
    )
    version.save!

    build_document_tree(version, result[:raw_xml]) if result[:raw_xml].present?
  rescue StandardError => e
    Rails.logger.error("[ParseLegislationDocumentJob] Failed for #{doc_ref}: #{e.message}")
    raise
  end

  private

  def extract_year(date_string)
    return nil unless date_string
    Date.parse(date_string).year
  rescue Date::Error
    nil
  end

  def parse_date(date_string)
    return nil unless date_string
    Date.parse(date_string)
  rescue Date::Error
    nil
  end

  def build_document_tree(version, xml)
    parser = detect_parser(xml)
    return unless parser

    nodes = parser.extract_body_hierarchy
    version.document_nodes.destroy_all
    persist_nodes(version, nodes, nil, 0)
  end

  def detect_parser(xml)
    if xml.include?("akomaNtoso") || xml.include?("docs.oasis-open.org/legaldocml")
      Parsers::AknParser.new(xml)
    elsif xml.include?("CONSLEG.ACT") || xml.include?("ENACTING.TERMS")
      Parsers::FormexParser.new(xml)
    end
  end

  def persist_nodes(version, nodes, parent, depth)
    nodes.each_with_index do |node_data, index|
      doc_node = version.document_nodes.create!(
        parent: parent,
        tree_path: node_data[:path],
        element_type: node_data[:element_type],
        eid: node_data[:eid],
        num: node_data[:num],
        heading: node_data[:heading],
        content_text: node_data[:content],
        position: index,
        depth: depth
      )

      persist_nodes(version, node_data[:children], doc_node, depth + 1) if node_data[:children].present?
    end
  end
end
```

- [ ] **Step 9: Run all job tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/jobs/
```

Expected: All 6 tests PASS.

- [ ] **Step 10: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/jobs/ test/jobs/ Gemfile Gemfile.lock test/test_helper.rb
git commit -m "feat: add jurisdiction sync and document parse jobs with fan-out pattern"
```

---

## Task 12: EUR-Lex RSS Service

**Files:**
- Create: `app/services/ingestion/eurlex_rss_service.rb`
- Create: `app/jobs/eurlex_rss_sync_job.rb`
- Create: `test/services/ingestion/eurlex_rss_service_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/services/ingestion/eurlex_rss_service_test.rb`:

```ruby
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/eurlex_rss_service_test.rb
```

Expected: FAIL — class not defined.

- [ ] **Step 3: Implement EurlexRssService**

Create `app/services/ingestion/eurlex_rss_service.rb`:

```ruby
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
```

- [ ] **Step 4: Create EurlexRssSyncJob**

Create `app/jobs/eurlex_rss_sync_job.rb`:

```ruby
class EurlexRssSyncJob < ApplicationJob
  queue_as :ingestion

  def perform
    jurisdiction = Jurisdiction.find_by!(code: "eu")
    service = Ingestion::EurlexRssService.new
    log = IngestionLog.create!(jurisdiction: jurisdiction, source_name: "eurlex_rss", status: "running")

    entries = service.fetch_new_entries

    entries.each do |entry|
      doc_ref = {
        celex_number: entry[:celex_number],
        title: entry[:title],
        frbr_uri: entry[:frbr_uri],
        legislation_type: detect_type_from_celex(entry[:celex_number]),
        date: entry[:published_at]&.to_date&.iso8601
      }
      ParseLegislationDocumentJob.perform_later("eu", doc_ref.to_json)
    end

    log.mark_completed!(documents_processed: entries.length)
  rescue StandardError => e
    log&.mark_failed!(e.message)
    Rails.logger.error("[EurlexRssSyncJob] Failed: #{e.message}")
  end

  private

  def detect_type_from_celex(celex)
    return "other" unless celex
    case celex[4]
    when "R" then "regulation"
    when "L" then "directive"
    when "D" then "decision"
    else "other"
    end
  end
end
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/services/ingestion/eurlex_rss_service_test.rb
```

Expected: All 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/services/ingestion/eurlex_rss_service.rb app/jobs/eurlex_rss_sync_job.rb test/services/ingestion/eurlex_rss_service_test.rb
git commit -m "feat: add EUR-Lex RSS feed polling service and job"
```

---

## Task 13: Solid Queue Recurring Schedule

**Files:**
- Create: `config/recurring.yml`

- [ ] **Step 1: Create recurring tasks config**

Create `config/recurring.yml`:

```yaml
production:
  eurlex_rss_sync:
    class: EurlexRssSyncJob
    schedule: "every 2 hours"
  eurlex_sparql_sync:
    class: JurisdictionSyncJob
    args: ["eu"]
    schedule: "every 6 hours"

development:
  eurlex_rss_sync:
    class: EurlexRssSyncJob
    schedule: "every 2 hours"
  eurlex_sparql_sync:
    class: JurisdictionSyncJob
    args: ["eu"]
    schedule: "every 6 hours"
```

- [ ] **Step 2: Verify config loads**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails runner "puts SolidQueue::RecurringTask.from_configuration.map(&:key)"
```

Expected: Lists the configured recurring tasks.

- [ ] **Step 3: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add config/recurring.yml
git commit -m "feat: add Solid Queue recurring schedule for EUR-Lex polling"
```

---

## Task 14: Routes & Controllers

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/dashboard_controller.rb`
- Create: `app/controllers/legislations_controller.rb`
- Create: `app/controllers/search_controller.rb`
- Create: `app/controllers/admin/ingestion_logs_controller.rb`
- Create: `test/controllers/dashboard_controller_test.rb`
- Create: `test/controllers/legislations_controller_test.rb`
- Create: `test/controllers/search_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/dashboard_controller_test.rb`:

```ruby
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    get root_url
    assert_response :success
  end
end
```

Create `test/controllers/legislations_controller_test.rb`:

```ruby
require "test_helper"

class LegislationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    @legislation = Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "GDPR",
      legislation_type: "regulation",
      year: 2016,
      status: "in_force"
    )
  end

  test "should get index" do
    get legislations_url
    assert_response :success
  end

  test "should get show" do
    get legislation_url(@legislation)
    assert_response :success
  end

  test "index filters by jurisdiction" do
    get legislations_url(jurisdiction: "eu")
    assert_response :success
  end
end
```

Create `test/controllers/search_controller_test.rb`:

```ruby
require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get search_url
    assert_response :success
  end

  test "search with query" do
    jurisdiction = Jurisdiction.create!(code: "eu", name: "European Union", jurisdiction_type: "supranational")
    Legislation.create!(
      jurisdiction: jurisdiction,
      frbr_uri: "/eli/reg/2016/679",
      title: "General Data Protection Regulation",
      legislation_type: "regulation",
      status: "in_force"
    )
    get search_url(q: "protection")
    assert_response :success
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/controllers/
```

Expected: FAIL — routes/controllers not defined.

- [ ] **Step 3: Set up routes**

Replace `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "dashboard#index"

  resources :legislations, only: [:index, :show]
  get "search", to: "search#index"

  namespace :admin do
    resources :ingestion_logs, only: [:index]
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 4: Create DashboardController**

Create `app/controllers/dashboard_controller.rb`:

```ruby
class DashboardController < ApplicationController
  def index
    @jurisdictions = Jurisdiction.all
    @legislation_count = Legislation.count
    @recent_logs = IngestionLog.recent.limit(10).includes(:jurisdiction)
    @stats = {
      total_legislations: @legislation_count,
      jurisdictions_active: Jurisdiction.joins(:legislations).distinct.count,
      last_sync: IngestionLog.where(status: "completed").order(created_at: :desc).first&.created_at
    }
  end
end
```

- [ ] **Step 5: Create LegislationsController**

Create `app/controllers/legislations_controller.rb`:

```ruby
class LegislationsController < ApplicationController
  def index
    @legislations = Legislation.includes(:jurisdiction).order(created_at: :desc)
    @legislations = @legislations.where(jurisdiction: Jurisdiction.find_by(code: params[:jurisdiction])) if params[:jurisdiction].present?
    @legislations = @legislations.by_type(params[:type]) if params[:type].present?
    @legislations = @legislations.by_year(params[:year]) if params[:year].present?
    @legislations = @legislations.where(status: params[:status]) if params[:status].present?
    @legislations = @legislations.page(params[:page]) if @legislations.respond_to?(:page)
  end

  def show
    @legislation = Legislation.find(params[:id])
    @versions = @legislation.legislation_versions.order(valid_from: :desc)
    @current_version = @versions.current.first || @versions.first
    @document_tree = @current_version&.document_nodes&.roots&.order(:position) || []
  end
end
```

- [ ] **Step 6: Create SearchController**

Create `app/controllers/search_controller.rb`:

```ruby
class SearchController < ApplicationController
  def index
    @query = params[:q]
    @results = if @query.present?
      Legislation.where("title ILIKE ?", "%#{Legislation.sanitize_sql_like(@query)}%")
                 .includes(:jurisdiction)
                 .order(created_at: :desc)
                 .limit(50)
    else
      Legislation.none
    end
  end
end
```

- [ ] **Step 7: Create Admin::IngestionLogsController**

Create `app/controllers/admin/ingestion_logs_controller.rb`:

```ruby
module Admin
  class IngestionLogsController < ApplicationController
    def index
      @logs = IngestionLog.recent.includes(:jurisdiction).limit(100)
    end
  end
end
```

- [ ] **Step 8: Run controller tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test test/controllers/
```

Expected: All tests PASS (views will be created in next task).

Note: Tests may fail on missing templates — that's expected and will be fixed in Task 15.

- [ ] **Step 9: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add config/routes.rb app/controllers/ test/controllers/
git commit -m "feat: add routes and controllers for dashboard, legislations, search, admin"
```

---

## Task 15: Minimal Hotwire Views

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/dashboard/index.html.erb`
- Create: `app/views/legislations/index.html.erb`
- Create: `app/views/legislations/show.html.erb`
- Create: `app/views/search/index.html.erb`
- Create: `app/views/admin/ingestion_logs/index.html.erb`

- [ ] **Step 1: Update application layout**

Replace `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>LexAggr - European Legislation Aggregator</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    <style>
      :root { --primary: #1a365d; --secondary: #2b6cb0; --bg: #f7fafc; --text: #2d3748; --border: #e2e8f0; }
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }
      nav { background: var(--primary); padding: 1rem 2rem; display: flex; gap: 2rem; align-items: center; }
      nav a { color: white; text-decoration: none; font-weight: 500; }
      nav a:hover { opacity: 0.8; }
      nav .brand { font-size: 1.25rem; font-weight: 700; margin-right: auto; }
      main { max-width: 1200px; margin: 2rem auto; padding: 0 1rem; }
      .card { background: white; border: 1px solid var(--border); border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; }
      .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
      .stat-card { background: white; border: 1px solid var(--border); border-radius: 8px; padding: 1.5rem; text-align: center; }
      .stat-card .number { font-size: 2rem; font-weight: 700; color: var(--secondary); }
      .stat-card .label { font-size: 0.875rem; color: #718096; }
      table { width: 100%; border-collapse: collapse; }
      th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid var(--border); }
      th { background: #edf2f7; font-weight: 600; font-size: 0.875rem; }
      .badge { display: inline-block; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: 600; }
      .badge-green { background: #c6f6d5; color: #276749; }
      .badge-red { background: #fed7d7; color: #9b2c2c; }
      .badge-yellow { background: #fefcbf; color: #975a16; }
      .badge-blue { background: #bee3f8; color: #2a4365; }
      input[type="text"], select { padding: 0.5rem; border: 1px solid var(--border); border-radius: 4px; font-size: 1rem; }
      .btn { padding: 0.5rem 1rem; background: var(--secondary); color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 0.875rem; text-decoration: none; }
      .btn:hover { opacity: 0.9; }
      .filters { display: flex; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; align-items: center; }
      .tree-node { margin-left: 1.5rem; border-left: 2px solid var(--border); padding-left: 1rem; margin-top: 0.5rem; }
      .tree-node-root { margin-left: 0; border-left: none; padding-left: 0; }
    </style>
  </head>
  <body>
    <nav>
      <span class="brand">LexAggr</span>
      <%= link_to "Dashboard", root_path %>
      <%= link_to "Legislation", legislations_path %>
      <%= link_to "Search", search_path %>
      <%= link_to "Ingestion Logs", admin_ingestion_logs_path %>
      <%= link_to "Jobs", "/jobs" %>
    </nav>
    <main>
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 2: Create dashboard view**

Create `app/views/dashboard/index.html.erb`:

```erb
<h1>Dashboard</h1>

<div class="stats">
  <div class="stat-card">
    <div class="number"><%= @stats[:total_legislations] %></div>
    <div class="label">Total Legislation</div>
  </div>
  <div class="stat-card">
    <div class="number"><%= @stats[:jurisdictions_active] %></div>
    <div class="label">Active Jurisdictions</div>
  </div>
  <div class="stat-card">
    <div class="number"><%= @stats[:last_sync]&.strftime("%b %d, %H:%M") || "Never" %></div>
    <div class="label">Last Sync</div>
  </div>
</div>

<div class="card">
  <h2>Jurisdictions</h2>
  <table>
    <thead>
      <tr>
        <th>Code</th>
        <th>Name</th>
        <th>Type</th>
        <th>Legislation Count</th>
      </tr>
    </thead>
    <tbody>
      <% @jurisdictions.each do |j| %>
        <tr>
          <td><strong><%= j.code.upcase %></strong></td>
          <td><%= j.name %></td>
          <td><span class="badge badge-blue"><%= j.jurisdiction_type %></span></td>
          <td><%= j.legislations.count %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>

<div class="card">
  <h2>Recent Ingestion Activity</h2>
  <% if @recent_logs.any? %>
    <table>
      <thead>
        <tr>
          <th>Source</th>
          <th>Jurisdiction</th>
          <th>Status</th>
          <th>Documents</th>
          <th>Time</th>
        </tr>
      </thead>
      <tbody>
        <% @recent_logs.each do |log| %>
          <tr>
            <td><%= log.source_name %></td>
            <td><%= log.jurisdiction.name %></td>
            <td>
              <span class="badge <%= log.status == 'completed' ? 'badge-green' : log.status == 'failed' ? 'badge-red' : 'badge-yellow' %>">
                <%= log.status %>
              </span>
            </td>
            <td><%= log.documents_processed %></td>
            <td><%= log.created_at.strftime("%b %d, %H:%M") %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% else %>
    <p>No ingestion activity yet. Run a sync to get started.</p>
  <% end %>
</div>
```

- [ ] **Step 3: Create legislations index view**

Create `app/views/legislations/index.html.erb`:

```erb
<h1>Legislation</h1>

<div class="filters">
  <%= form_tag legislations_path, method: :get, data: { turbo_frame: "legislations" } do %>
    <%= select_tag :jurisdiction, options_from_collection_for_select(Jurisdiction.all, :code, :name, params[:jurisdiction]), include_blank: "All Jurisdictions" %>
    <%= select_tag :type, options_for_select([["Regulation", "regulation"], ["Directive", "directive"], ["Decision", "decision"]], params[:type]), include_blank: "All Types" %>
    <%= select_tag :status, options_for_select([["In Force", "in_force"], ["Repealed", "repealed"], ["Pending", "pending"]], params[:status]), include_blank: "All Statuses" %>
    <%= submit_tag "Filter", class: "btn" %>
  <% end %>
</div>

<%= turbo_frame_tag "legislations" do %>
  <div class="card">
    <table>
      <thead>
        <tr>
          <th>Title</th>
          <th>Jurisdiction</th>
          <th>Type</th>
          <th>Year</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <% @legislations.each do |leg| %>
          <tr>
            <td><%= link_to leg.title.truncate(80), legislation_path(leg) %></td>
            <td><%= leg.jurisdiction.code.upcase %></td>
            <td><span class="badge badge-blue"><%= leg.legislation_type %></span></td>
            <td><%= leg.year %></td>
            <td>
              <span class="badge <%= leg.status == 'in_force' ? 'badge-green' : 'badge-red' %>">
                <%= leg.status&.humanize %>
              </span>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    <% if @legislations.empty? %>
      <p style="padding: 1rem; text-align: center; color: #718096;">No legislation found. Run an ingestion job to populate data.</p>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 4: Create legislations show view**

Create `app/views/legislations/show.html.erb`:

```erb
<h1><%= @legislation.title %></h1>

<div class="card">
  <h2>Metadata</h2>
  <table>
    <tr><th>FRBR URI</th><td><%= @legislation.frbr_uri %></td></tr>
    <tr><th>CELEX</th><td><%= @legislation.celex_number %></td></tr>
    <tr><th>ELI URI</th><td><%= @legislation.eli_uri %></td></tr>
    <tr><th>Jurisdiction</th><td><%= @legislation.jurisdiction.name %></td></tr>
    <tr><th>Type</th><td><span class="badge badge-blue"><%= @legislation.legislation_type %></span></td></tr>
    <tr><th>Year</th><td><%= @legislation.year %></td></tr>
    <tr><th>Status</th><td><span class="badge <%= @legislation.status == 'in_force' ? 'badge-green' : 'badge-red' %>"><%= @legislation.status&.humanize %></span></td></tr>
  </table>
</div>

<% if @versions.any? %>
  <div class="card">
    <h2>Versions (<%= @versions.count %>)</h2>
    <table>
      <thead>
        <tr><th>Language</th><th>Valid From</th><th>Valid To</th><th>Type</th></tr>
      </thead>
      <tbody>
        <% @versions.each do |v| %>
          <tr>
            <td><%= v.language %></td>
            <td><%= v.valid_from %></td>
            <td><%= v.valid_to || "Current" %></td>
            <td><%= v.version_type %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>

<% if @document_tree.any? %>
  <div class="card">
    <h2>Document Structure</h2>
    <% @document_tree.each do |node| %>
      <%= render partial: "legislations/document_node", locals: { node: node, level: 0 } %>
    <% end %>
  </div>
<% end %>
```

Create `app/views/legislations/_document_node.html.erb`:

```erb
<div class="tree-node <%= 'tree-node-root' if level == 0 %>">
  <strong><%= node.element_type.capitalize %><%= " #{node.num}" if node.num.present? %></strong>
  <% if node.heading.present? %>
    — <%= node.heading %>
  <% end %>
  <% if node.content_text.present? %>
    <p style="margin-top: 0.25rem; color: #4a5568;"><%= node.content_text.truncate(200) %></p>
  <% end %>
  <% node.children.order(:position).each do |child| %>
    <%= render partial: "legislations/document_node", locals: { node: child, level: level + 1 } %>
  <% end %>
</div>
```

- [ ] **Step 5: Create search view**

Create `app/views/search/index.html.erb`:

```erb
<h1>Search Legislation</h1>

<div class="card">
  <%= form_tag search_path, method: :get do %>
    <div style="display: flex; gap: 0.5rem;">
      <%= text_field_tag :q, @query, placeholder: "Search legislation titles...", style: "flex: 1;" %>
      <%= submit_tag "Search", class: "btn" %>
    </div>
  <% end %>
</div>

<% if @query.present? %>
  <div class="card">
    <h2>Results for "<%= @query %>" (<%= @results.count %>)</h2>
    <% if @results.any? %>
      <table>
        <thead>
          <tr><th>Title</th><th>Jurisdiction</th><th>Type</th><th>Year</th></tr>
        </thead>
        <tbody>
          <% @results.each do |leg| %>
            <tr>
              <td><%= link_to leg.title.truncate(80), legislation_path(leg) %></td>
              <td><%= leg.jurisdiction.code.upcase %></td>
              <td><span class="badge badge-blue"><%= leg.legislation_type %></span></td>
              <td><%= leg.year %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p style="text-align: center; color: #718096;">No results found.</p>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 6: Create ingestion logs view**

Create `app/views/admin/ingestion_logs/index.html.erb`:

```erb
<h1>Ingestion Logs</h1>

<div class="card">
  <table>
    <thead>
      <tr>
        <th>Time</th>
        <th>Jurisdiction</th>
        <th>Source</th>
        <th>Status</th>
        <th>Documents</th>
        <th>ETag</th>
        <th>Error</th>
      </tr>
    </thead>
    <tbody>
      <% @logs.each do |log| %>
        <tr>
          <td><%= log.created_at.strftime("%Y-%m-%d %H:%M") %></td>
          <td><%= log.jurisdiction.code.upcase %></td>
          <td><%= log.source_name %></td>
          <td>
            <span class="badge <%= log.status == 'completed' ? 'badge-green' : log.status == 'failed' ? 'badge-red' : 'badge-yellow' %>">
              <%= log.status %>
            </span>
          </td>
          <td><%= log.documents_processed %></td>
          <td><%= log.last_etag&.truncate(20) %></td>
          <td style="color: #e53e3e;"><%= log.error_message&.truncate(50) %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
  <% if @logs.empty? %>
    <p style="padding: 1rem; text-align: center; color: #718096;">No ingestion logs yet.</p>
  <% end %>
</div>
```

- [ ] **Step 7: Run all tests**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git add app/views/ config/routes.rb
git commit -m "feat: add minimal Hotwire UI with dashboard, legislation browser, search, and ingestion logs"
```

---

## Task 16: Full Test Suite Run & Final Push

**Files:** None new — verification only.

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails test
```

Expected: All tests PASS, zero failures.

- [ ] **Step 2: Verify Rails boots and serves pages**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
bin/rails runner "puts 'Models: ' + ApplicationRecord.descendants.map(&:name).join(', ')"
```

Expected: Lists Jurisdiction, Legislation, LegislationVersion, DocumentNode, IngestionLog.

- [ ] **Step 3: Push all commits to GitHub**

```bash
cd /Users/jurgenleka/Public/WorkRepos/personal-work/LexAggr
git push origin main
```

Expected: All commits pushed to `github.com/jouleka/LexAggr`.
