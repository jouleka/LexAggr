class AddTsvectorTriggers < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION legislations_searchable_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.searchable :=
          setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER legislations_searchable_update
        BEFORE INSERT OR UPDATE OF title
        ON legislations
        FOR EACH ROW
        EXECUTE FUNCTION legislations_searchable_trigger();
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION document_nodes_searchable_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.searchable :=
          setweight(to_tsvector('english', coalesce(NEW.heading, '')), 'B') ||
          setweight(to_tsvector('english', coalesce(NEW.content_text, '')), 'D');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER document_nodes_searchable_update
        BEFORE INSERT OR UPDATE OF heading, content_text
        ON document_nodes
        FOR EACH ROW
        EXECUTE FUNCTION document_nodes_searchable_trigger();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS legislations_searchable_update ON legislations;
      DROP FUNCTION IF EXISTS legislations_searchable_trigger();

      DROP TRIGGER IF EXISTS document_nodes_searchable_update ON document_nodes;
      DROP FUNCTION IF EXISTS document_nodes_searchable_trigger();
    SQL
  end
end
