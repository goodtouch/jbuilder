require 'test/unit'
require 'active_support/test_case'

require 'jbuilder'

class XmlTest < ActiveSupport::TestCase
  test "single key" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.content "hello"
    end
  
    assert_equal "hello", Hash.from_xml(xml)['root']["content"]
  end

  test "single key with false value" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.content false
    end

    assert_equal false, Hash.from_xml(xml)['root']["content"]
  end

  test "single key with nil value" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.content nil
    end

    assert Hash.from_xml(xml)['root'].has_key?("content")
    assert_equal nil, Hash.from_xml(xml)['root']["content"]
  end

  test "multiple keys" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.title "hello"
      xml.content "world"
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "hello", parsed["title"]
      assert_equal "world", parsed["content"]
    end
  end
  
  test "extracting from object" do
    person = Struct.new(:name, :age).new("David", 32)
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.extract! person, :name, :age
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "David", parsed["name"]
      assert_equal 32, parsed["age"]
    end
  end
  
  test "extracting from object using call style for 1.9" do
    person = Struct.new(:name, :age).new("David", 32)
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.(person, :name, :age)
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "David", parsed["name"]
      assert_equal 32, parsed["age"]
    end
  end
  
  test "nesting single child with block" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.author do |xml|
        xml.name "David"
        xml.age  32
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32, parsed["author"]["age"]
    end
  end
  
  test "nesting multiple children with block" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.comments do |xml|
        xml.child! { |xml| xml.content "hello" }
        xml.child! { |xml| xml.content "world" }
      end
    end

    Hash.from_xml(xml)['root'].tap do |parsed|
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
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.author person, :name, :age
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32,      parsed["author"]["age"]
    end
  end
  
  test "nesting multiple children from array" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.comments comments, :content
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal ["content"], parsed["comments"].first.keys
      assert_equal "hello", parsed["comments"].first["content"]
      assert_equal "world", parsed["comments"].second["content"]
    end
  end
  
  test "nesting multiple children from array when child array is empty" do
    comments = []
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.name "Parent"
      xml.comments comments, :content
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "Parent", parsed["name"]
      assert_equal [], parsed["comments"]
    end
  end
  
  test "nesting multiple children from array with inline loop" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.comments comments do |xml, comment|
        xml.content comment.content
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal ["content"], parsed["comments"].first.keys
      assert_equal "hello", parsed["comments"].first["content"]
      assert_equal "world", parsed["comments"].second["content"]
    end
  end

  test "nesting multiple children from array with inline loop on root" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.(comments) do |xml, comment|
        xml.content comment.content
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "hello", parsed.first["content"]
      assert_equal "world", parsed.second["content"]
    end
  end
  
  test "array nested inside nested hash" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.author do |xml|
        xml.name "David"
        xml.age  32
  
        xml.comments do |xml|
          xml.child! { |xml| xml.content "hello" }
          xml.child! { |xml| xml.content "world" }
        end
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "hello", parsed["author"]["comments"].first["content"]
      assert_equal "world", parsed["author"]["comments"].second["content"]
    end
  end
  
  test "array nested inside array" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.comments do |xml|
        xml.child! do |xml|
          xml.authors do |xml|
            xml.child! do |xml|
              xml.name "david"
            end
          end
        end
      end
    end
  
    assert_equal "david", Hash.from_xml(xml)['root']["comments"].first["authors"].first["name"]
  end
  
  test "top-level array" do
    comments = [ Struct.new(:content, :id).new("hello", 1), Struct.new(:content, :id).new("world", 2) ]

    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.array!(comments) do |xml, comment|
        xml.content comment.content
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "hello", parsed.first["content"]
      assert_equal "world", parsed.second["content"]
    end
  end
  
  test "empty top-level array" do
    comments = []
  
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.array!(comments) do |xml, comment|
        xml.content comment.content
      end
    end
  
    assert_equal [], Hash.from_xml(xml)['root']
  end
  
  test "dynamically set a key/value" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.set!(:each, "stuff")
    end
  
    assert_equal "stuff", Hash.from_xml(xml)['root']["each"]
  end

  test "dynamically set a key/nested child with block" do
    xml = Jbuilder.encode(:xml, :root => 'root') do |xml|
      xml.set!(:author) do |xml|
        xml.name "David"
        xml.age 32
      end
    end
  
    Hash.from_xml(xml)['root'].tap do |parsed|
      assert_equal "David", parsed["author"]["name"]
      assert_equal 32, parsed["author"]["age"]
    end
  end
end
