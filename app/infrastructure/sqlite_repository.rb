# typed: true

require "json"
require "fileutils"
require "sqlite3"
require "sorbet-runtime"
require_relative "../app"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../domain/field"
require_relative "../domain/attribute"

module App::Infrastructure
  class SqliteRepository
    extend T::Generic
    extend T::Sig

    Elem = type_member

    sig { params(type: T::Class[Object], db_path: String).void }
    def initialize(type:, db_path: "db/app.sqlite3")
      @type = T.let(type, T::Class[Object])
      unless schema_repo? || entity_repo?
        raise ArgumentError, "SqliteRepository only supports App::Domain::Schema or App::Domain::Entity"
      end
      @db_path = T.let(db_path, String)
      prepare_storage!
      @db = T.let(SQLite3::Database.new(@db_path), SQLite3::Database)
      @db.results_as_hash = true
      setup_schema!
    end

    sig { params(item: Elem).returns(Elem) }
    def add(item:)
      validate_type!(item:)
      if schema_repo?
        insert_schema(item)
      elsif entity_repo?
        insert_entity(item)
      else
        raise ArgumentError, "Unsupported type: #{@type}"
      end
      item
    end

    sig { returns(T::Array[Elem]) }
    def all
      if schema_repo?
        fetch_schemas
      elsif entity_repo?
        fetch_entities
      else
        raise ArgumentError, "Unsupported type: #{@type}"
      end
    end

    sig { params(block: T.proc.params(item: Elem).returns(T::Boolean)).returns(T.nilable(Elem)) }
    def find_by(&block)
      all.find(&block)
    end

    sig { returns(T::Array[Elem]) }
    def clear
      if schema_repo?
        @db.execute("DELETE FROM schemas")
      elsif entity_repo?
        @db.execute("DELETE FROM entities")
      end
      []
    end

    private

    sig { void }
    def prepare_storage!
      FileUtils.mkdir_p(File.dirname(@db_path))
    end

    sig { void }
    def setup_schema!
      if schema_repo?
        @db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS schemas (
            name TEXT PRIMARY KEY,
            fields TEXT NOT NULL
          )
        SQL
      elsif entity_repo?
        @db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS entities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            schema_name TEXT NOT NULL,
            attributes TEXT NOT NULL
          )
        SQL
      end
    end

    sig { returns(T::Boolean) }
    def schema_repo?
      @type == App::Domain::Schema
    end

    sig { returns(T::Boolean) }
    def entity_repo?
      @type == App::Domain::Entity
    end

    sig { params(item: Elem).void }
    def validate_type!(item:)
      return if item.is_a?(@type)

      raise ArgumentError, "Expected #{@type}, got #{item.class}"
    end

    sig { params(schema: App::Domain::Schema).void }
    def insert_schema(schema)
      payload = JSON.generate(
        schema.fields.map do |name, type|
          { "name" => name.to_s, "type" => type.to_s }
        end
      )
      @db.execute(
        "INSERT INTO schemas (name, fields) VALUES (?, ?)",
        [schema.name, payload]
      )
    end

    sig { params(entity: App::Domain::Entity).void }
    def insert_entity(entity)
      payload = JSON.generate(
        entity.attributes.map do |attr|
          { "name" => attr.name.to_s, "value" => attr.value }
        end
      )
      @db.execute(
        "INSERT INTO entities (schema_name, attributes) VALUES (?, ?)",
        [entity.schema_name, payload]
      )
    end

    sig { returns(T::Array[Elem]) }
    def fetch_schemas
      rows = @db.execute("SELECT name, fields FROM schemas ORDER BY name")
      rows.map do |row|
        fields = JSON.parse(row["fields"]).map do |field|
          App::Domain::Field.new(name: field["name"], type: field["type"])
        end
        App::Domain::Schema.new(name: row["name"], fields: fields)
      end
    end

    sig { returns(T::Array[Elem]) }
    def fetch_entities
      rows = @db.execute("SELECT schema_name, attributes FROM entities ORDER BY id")
      rows.map do |row|
        attrs = JSON.parse(row["attributes"]).map do |attr|
          App::Domain::Attribute.new(name: attr["name"], value: attr["value"])
        end
        App::Domain::Entity.new(schema_name: row["schema_name"], attributes: attrs)
      end
    end
  end
end
