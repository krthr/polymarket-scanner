require "./models"

module PolyScan
  class OrderBookCache
    def initialize
      @books = {} of String => OrderBook
    end

    def put(book : OrderBook) : Nil
      @books[book.token_id] = book
    end

    def get(token_id : String) : OrderBook?
      @books[token_id]?
    end

    def all : Array(OrderBook)
      @books.values
    end

    def size : Int32
      @books.size
    end
  end
end
