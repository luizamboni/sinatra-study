# typed: true

require "json"
require "securerandom"
require "sorbet-runtime"
require "google/cloud/spanner"
require "google/cloud/spanner/admin/database"
require_relative "../app"
require_relative "../domain/schema"
require_relative "../domain/entity"
require_relative "../domain/field"
require_relative "../domain/attribute"

module App::Infrastructure
  class SpannerRepository
    extend T::Generic
    extend T::Sig

    Elem = type_member

    sig do
      params(
        type: T::Class[Object],
        project_id: String,
        instance_id: String,
        database_id: String
      ).void
    end
    def initialize(type:, project_id:, instance_id:, database_id:)
      @type = T.let(type, T::Class[Object])
      unless schema_repo? || entity_repo?
        raise ArgumentError, "SpannerRepository only supports App::Domain::Schema or App::Domain::Entity"
      end

      @project_id = T.let(project_id, String)
      @instance_id = T.let(instance_id, String)
      @database_id = T.let(database_id, String)

      @spanner = T.let(Google::Cloud::Spanner.new(project: @project_id), Google::Cloud::Spanner::Project)
      @client = T.let(@spanner.client(@instance_id, @database_id), Google::Cloud::Spanner::Client)

      ensure_tables!
    end

    sig { params(item: Elem).returns(Elem) }
    def add(item:)
      validate_type!(item:)
      if schema_repo?
        insert_schema(T.cast(item, App::Domain::Schema))
      elsif entity_repo?
        insert_entity(T.cast(item, App::Domain::Entity))
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
        @client.transaction { |tx| tx.execute_update("DELETE FROM schemas WHERE TRUE") }
      elsif entity_repo?
        @client.transaction { |tx| tx.execute_update("DELETE FROM entities WHERE TRUE") }
      end
      []
    end

    private

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
      return if T.unsafe(item).is_a?(@type)

      raise ArgumentError, "Expected #{@type}, got #{T.unsafe(item).class}"
    end

    sig { void }
    def ensure_tables!
      missing = []
      missing << "schemas" unless table_exists?("schemas")
      missing << "entities" unless table_exists?("entities")
      return if missing.empty?

      ddl = []
      if missing.include?("schemas")
        ddl << <<~SQL
          CREATE TABLE schemas (
            name STRING(1024) NOT NULL,
            fields STRING(MAX) NOT NULL
          ) PRIMARY KEY (name)
        SQL
      end

      if missing.include?("entities")
        ddl << <<~SQL
          CREATE TABLE entities (
            id STRING(36) NOT NULL,
            schema_name STRING(1024) NOT NULL,
            attributes STRING(MAX) NOT NULL
          ) PRIMARY KEY (id)
        SQL
      end

      db = @spanner.database(@instance_id, @database_id)
      job = db.update statements: ddl
      job.wait_until_done!
    end

    sig { params(table_name: String).returns(T::Boolean) }
    def table_exists?(table_name)
      results = @client.execute_query(
        "SELECT table_name FROM information_schema.tables WHERE table_name = @name",
        params: { name: table_name }
      )
      results.rows.any?
    end

    sig { params(schema: App::Domain::Schema).void }
    def insert_schema(schema)
      payload = JSON.generate(
        schema.fields.map do |name, type|
          { "name" => name.to_s, "type" => type.to_s }
        end
      )
      @client.commit do |c|
        c.insert "schemas", [{ name: schema.name, fields: payload }]
      end
    end

    sig { params(entity: App::Domain::Entity).void }
    def insert_entity(entity)
      payload = JSON.generate(
        entity.attributes.map do |attr|
          { "name" => attr.name.to_s, "value" => attr.value }
        end
      )
      @client.commit do |c|
        c.insert "entities", [{
          id: SecureRandom.uuid,
          schema_name: entity.schema_name,
          attributes: payload
        }]
      end
    end

    sig { returns(T::Array[Elem]) }
    def fetch_schemas
      rows = @client.execute_query("SELECT name, fields FROM schemas ORDER BY name")
      rows.rows.map do |row|
        fields = JSON.parse(row[:fields]).map do |field|
          App::Domain::Field.new(name: field["name"], type: field["type"])
        end
        App::Domain::Schema.new(name: row[:name], fields: fields)
      end
    end

    sig { returns(T::Array[Elem]) }
    def fetch_entities
      rows = @client.execute_query("SELECT schema_name, attributes FROM entities ORDER BY id")
      rows.rows.map do |row|
        attrs = JSON.parse(row[:attributes]).map do |attr|
          App::Domain::Attribute.new(name: attr["name"], value: attr["value"])
        end
        App::Domain::Entity.new(schema_name: row[:schema_name], attributes: attrs)
      end
    end
  end
end
