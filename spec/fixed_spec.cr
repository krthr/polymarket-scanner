require "./spec_helper"

describe PolyScan::Fixed do
  it "parses and formats fixed decimal strings" do
    value = PolyScan::Fixed.parse("0.123456")
    value.atoms.should eq(123_456_i64)
    value.to_s.should eq("0.123456")

    PolyScan::Fixed.parse("1.230000").to_s.should eq("1.23")
    PolyScan::Fixed.parse("-2.500000").format(2).should eq("-2.50")
    PolyScan::Fixed.parse("3").format.should eq("3.000000")
  end

  it "rejects excess precision instead of silently using floating point" do
    expect_raises(ArgumentError) do
      PolyScan::Fixed.parse("0.1234567")
    end
  end

  it "multiplies and divides using scaled integers" do
    (fp("0.500000") * fp("2.000000")).should eq(fp("1.000000"))
    (fp("1.000000") / fp("4.000000")).should eq(fp("0.250000"))
  end
end
