require "json"
require "yaml"

module PolyScan
  struct Fixed
    include Comparable(Fixed)

    SCALE_DIGITS =             6
    SCALE        = 1_000_000_i64

    getter atoms : Int64

    def initialize(@atoms : Int64)
    end

    def self.zero : Fixed
      new(0_i64)
    end

    def self.one : Fixed
      new(SCALE)
    end

    def self.from_atoms(atoms : Int64) : Fixed
      new(atoms)
    end

    def self.parse(value : String) : Fixed
      s = value.strip
      raise ArgumentError.new("empty fixed decimal") if s.empty?

      sign = 1_i64
      if s.starts_with?("-")
        sign = -1_i64
        s = s[1..]
      elsif s.starts_with?("+")
        s = s[1..]
      end

      raise ArgumentError.new("invalid fixed decimal: #{value}") if s.empty?

      whole_part, frac_part = if dot = s.index('.')
                                {s[0...dot], s[(dot + 1)..]}
                              else
                                {s, ""}
                              end

      whole = whole_part.empty? ? 0_i64 : whole_part.to_i64
      frac = frac_part
      if frac.size > SCALE_DIGITS
        extra = frac[SCALE_DIGITS..]
        unless extra.each_char.all? { |ch| ch == '0' }
          raise ArgumentError.new("too many fixed decimal places: #{value}")
        end
        frac = frac[0, SCALE_DIGITS]
      end
      frac = frac.ljust(SCALE_DIGITS, '0')
      frac_atoms = frac.empty? ? 0_i64 : frac.to_i64

      new(sign * (whole * SCALE + frac_atoms))
    end

    def self.parse(value : Int32) : Fixed
      new(value.to_i64 * SCALE)
    end

    def self.parse(value : Int64) : Fixed
      new(value * SCALE)
    end

    def <=>(other : Fixed)
      @atoms <=> other.atoms
    end

    def +(other : Fixed) : Fixed
      Fixed.new(@atoms + other.atoms)
    end

    def -(other : Fixed) : Fixed
      Fixed.new(@atoms - other.atoms)
    end

    def - : Fixed
      Fixed.new(-@atoms)
    end

    def *(other : Fixed) : Fixed
      Fixed.new((@atoms.to_i128 * other.atoms.to_i128 // SCALE).to_i64)
    end

    def /(other : Fixed) : Fixed
      raise DivisionByZeroError.new if other.atoms == 0
      Fixed.new((@atoms.to_i128 * SCALE // other.atoms.to_i128).to_i64)
    end

    def /(divisor : Int32) : Fixed
      raise DivisionByZeroError.new if divisor == 0
      Fixed.new(@atoms // divisor)
    end

    def /(divisor : Int64) : Fixed
      raise DivisionByZeroError.new if divisor == 0
      Fixed.new(@atoms // divisor)
    end

    def bps(rate_bps : Int32) : Fixed
      Fixed.new((@atoms.to_i128 * rate_bps.to_i128 // 10_000).to_i64)
    end

    def min(other : Fixed) : Fixed
      self <= other ? self : other
    end

    def max(other : Fixed) : Fixed
      self >= other ? self : other
    end

    def positive? : Bool
      @atoms > 0
    end

    def negative? : Bool
      @atoms < 0
    end

    def zero? : Bool
      @atoms == 0
    end

    def abs : Fixed
      Fixed.new(@atoms.abs)
    end

    def format(decimals : Int32 = SCALE_DIGITS) : String
      raise ArgumentError.new("negative decimals") if decimals < 0
      raise ArgumentError.new("too many decimals") if decimals > SCALE_DIGITS

      sign = @atoms < 0 ? "-" : ""
      abs_atoms = @atoms.abs
      whole = abs_atoms // SCALE
      frac = (abs_atoms % SCALE).to_s.rjust(SCALE_DIGITS, '0')
      return "#{sign}#{whole}" if decimals == 0

      "#{sign}#{whole}.#{frac[0, decimals]}"
    end

    def to_s(io : IO) : Nil
      sign = @atoms < 0 ? "-" : ""
      abs_atoms = @atoms.abs
      whole = abs_atoms // SCALE
      frac = (abs_atoms % SCALE).to_s.rjust(SCALE_DIGITS, '0').rstrip('0')
      if frac.empty?
        io << sign << whole
      else
        io << sign << whole << "." << frac
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s)
    end

    module JSONConverter
      def self.from_json(pull : JSON::PullParser) : Fixed
        Fixed.parse(pull.read_string)
      end

      def self.to_json(value : Fixed, json : JSON::Builder) : Nil
        value.to_json(json)
      end
    end

    module YAMLConverter
      def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Fixed
        Fixed.parse(node.value)
      end

      def self.to_yaml(value : Fixed, yaml : YAML::Builder) : Nil
        yaml.scalar(value.to_s)
      end
    end
  end
end
