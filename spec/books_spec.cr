require "./spec_helper"

describe PolyScan::OrderBook do
  it "flags invalid books" do
    book = PolyScan::Clients::ClobClient.book_from_file("spec/fixtures/invalid_book.json")
    errors = book.validation_errors
    errors.should contain("bids price out of range")
    errors.should contain("asks size must be positive")
    errors.should contain("crossed book")
  end
end
