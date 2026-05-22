require "yaml"
require "./fixed"

module PolyScan
  class RelationshipRule
    getter id : String
    getter type : String
    getter description : String?
    getter from_token_id : String?
    getter to_token_id : String?
    getter token_ids : Array(String)
    getter confidence : Fixed
    getter quality : Fixed
    getter verified_exhaustive : Bool

    def initialize(@id : String, @type : String, @description : String?, @from_token_id : String?, @to_token_id : String?, @token_ids : Array(String), @confidence : Fixed, @quality : Fixed, @verified_exhaustive : Bool = false)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "type", @type
        json.field "description", @description
        json.field "from_token_id", @from_token_id
        json.field "to_token_id", @to_token_id
        json.field "token_ids", @token_ids
        json.field "confidence", @confidence
        json.field "quality", @quality
        json.field "verified_exhaustive", @verified_exhaustive
      end
    end
  end

  class RelationshipGraph
    SUPPORTED_TYPES = Set{
      "implication",
      "mutually_exclusive",
      "exhaustive_group",
      "complement",
      "correlated_group",
    }

    getter rules : Array(RelationshipRule)

    def initialize(@rules : Array(RelationshipRule))
    end

    def self.empty : RelationshipGraph
      new([] of RelationshipRule)
    end

    def self.load(path : String) : RelationshipGraph
      return empty unless File.exists?(path)

      doc = YAML.parse(File.read(path))
      raw_rules = doc["rules"]?.try(&.as_a) || [] of YAML::Any
      rules = raw_rules.map { |node| parse_rule(node) }
      new(rules)
    end

    def by_type(type : String) : Array(RelationshipRule)
      @rules.select { |rule| rule.type == type }
    end

    private def self.parse_rule(node : YAML::Any) : RelationshipRule
      id = string(node, "id")
      type = string(node, "type")
      raise ArgumentError.new("unsupported relationship type #{type.inspect} for #{id}") unless SUPPORTED_TYPES.includes?(type)

      RelationshipRule.new(
        id: id,
        type: type,
        description: optional_string(node, "description"),
        from_token_id: optional_string(node, "from_token_id"),
        to_token_id: optional_string(node, "to_token_id"),
        token_ids: string_array(node, "token_ids"),
        confidence: fixed(node, "confidence", "0.500000"),
        quality: fixed(node, "quality", "0.500000"),
        verified_exhaustive: bool(node, "verified_exhaustive", false)
      )
    end

    private def self.string(node : YAML::Any, key : String) : String
      node[key]?.try(&.as_s) || raise ArgumentError.new("relationship rule missing #{key}")
    end

    private def self.optional_string(node : YAML::Any, key : String) : String?
      node[key]?.try(&.as_s)
    end

    private def self.string_array(node : YAML::Any, key : String) : Array(String)
      node[key]?.try(&.as_a.map(&.as_s)) || [] of String
    end

    private def self.fixed(node : YAML::Any, key : String, default : String) : Fixed
      Fixed.parse(node[key]?.try(&.as_s) || default)
    end

    private def self.bool(node : YAML::Any, key : String, default : Bool) : Bool
      value = node[key]?
      value ? value.as_bool : default
    end
  end
end
