require 'test/unit'
require 'active_support/test_case'

require 'jbuilder'

class MsgPackTest < ActiveSupport::TestCase
  test "single key" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.content "hello"
    end
  
    assert_equal "hello", MessagePack.unpack(msgpack)["content"]
  end

  test "single key with false value" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.content false
    end

    assert_equal false, MessagePack.unpack(msgpack)["content"]
  end

  test "single key with nil value" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.content nil
    end

    assert MessagePack.unpack(msgpack).has_key?("content")
    assert_equal nil, MessagePack.unpack(msgpack)["content"]
  end

  test "multiple keys" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.title "hello"
      msgpack.content "world"
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "hello", parsed["title"]
      assert_equal "world", parsed["content"]
    end
  end
  
  test "extracting from object" do
    person = Struct.new(:name, :age).new("David", 32)
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.extract! person, :name, :age
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "David", parsed["name"]
      assert_equal 32, parsed["age"]
    end
  end
  
  test "extracting from object using call style for 1.9" do
    person = Struct.new(:name, :age).new("David", 32)
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.(person, :name, :age)
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "David", parsed["name"]
      assert_equal 32, parsed["age"]
    end
  end
  
  test "nesting single child with block" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.author do |msgpack|
        msgpack.name "David"
        msgpack.age  32
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32, parsed["author"]["age"]
    end
  end
  
  test "nesting multiple children with block" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.comments do |msgpack|
        msgpack.child! { |msgpack| msgpack.content "hello" }
        msgpack.child! { |msgpack| msgpack.content "world" }
      end
    end

    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "hello", parsed["comments"].first["content"]
      assert_equal "world", parsed["comments"].second["content"]
    end
  end
  
  test "nesting single child with inline extract" do
    person = Class.new do
      attr_reader :name, :age
  
      def initialize(name, age)
        @name, @age = name, age
      end
    end.new("David", 32)
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.author person, :name, :age
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32,      parsed["author"]["age"]
    end
  end
  
  test "nesting multiple children from array" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.comments comments, :content
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal ["content"], parsed["comments"].first.keys
      assert_equal "hello", parsed["comments"].first["content"]
      assert_equal "world", parsed["comments"].second["content"]
    end
  end
  
  test "nesting multiple children from array when child array is empty" do
    comments = []
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.name "Parent"
      msgpack.comments comments, :content
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "Parent", parsed["name"]
      assert_equal [], parsed["comments"]
    end
  end
  
  test "nesting multiple children from array with inline loop" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.comments comments do |msgpack, comment|
        msgpack.content comment.content
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal ["content"], parsed["comments"].first.keys
      assert_equal "hello", parsed["comments"].first["content"]
      assert_equal "world", parsed["comments"].second["content"]
    end
  end

  test "nesting multiple children from array with inline loop on root" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.(comments) do |msgpack, comment|
        msgpack.content comment.content
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "hello", parsed.first["content"]
      assert_equal "world", parsed.second["content"]
    end
  end
  
  test "array nested inside nested hash" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.author do |msgpack|
        msgpack.name "David"
        msgpack.age  32
  
        msgpack.comments do |msgpack|
          msgpack.child! { |msgpack| msgpack.content "hello" }
          msgpack.child! { |msgpack| msgpack.content "world" }
        end
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "hello", parsed["author"]["comments"].first["content"]
      assert_equal "world", parsed["author"]["comments"].second["content"]
    end
  end
  
  test "array nested inside array" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.comments do |msgpack|
        msgpack.child! do |msgpack|
          msgpack.authors do |msgpack|
            msgpack.child! do |msgpack|
              msgpack.name "david"
            end
          end
        end
      end
    end
  
    assert_equal "david", MessagePack.unpack(msgpack)["comments"].first["authors"].first["name"]
  end
  
  test "top-level array" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]

    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.array!(comments) do |msgpack, comment|
        msgpack.content comment.content
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "hello", parsed.first["content"]
      assert_equal "world", parsed.second["content"]
    end
  end
  
  test "empty top-level array" do
    comments = []
  
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.array!(comments) do |msgpack, comment|
        msgpack.content comment.content
      end
    end
  
    assert_equal [], MessagePack.unpack(msgpack)
  end
  
  test "dynamically set a key/value" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.set!(:each, "stuff")
    end
  
    assert_equal "stuff", MessagePack.unpack(msgpack)["each"]
  end

  test "dynamically set a key/nested child with block" do
    msgpack = Jbuilder.encode(:msgpack, :root => 'root') do |msgpack|
      msgpack.set!(:author) do |msgpack|
        msgpack.name "David"
        msgpack.age 32
      end
    end
  
    MessagePack.unpack(msgpack).tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32, parsed["author"]["age"]
    end
  end
end
