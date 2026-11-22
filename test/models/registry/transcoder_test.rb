require 'test_helper'

module Registry
  # Registry::Transcoder::BaseTest and ::DSLTest cover the transcoder plumbing;
  # this covers the set of transcoders the engine ships with (see
  # lib/registry/transcoder.rb), which is what decides how a value written to
  # the registry comes back out of it.
  class TranscoderTest < TestCase

    test 'array round trip' do
      assert_equal '[1,2,3]',  Transcoder.to_db([1, 2, 3])
      assert_equal [1, 2, 3],  Transcoder.from_db('[1,2,3]')
    end

    test 'array of mixed types round trip' do
      assert_equal '[1,true,:sym]',   Transcoder.to_db([1, true, :sym])
      assert_equal [1, true, :sym],   Transcoder.from_db('[1,true,:sym]')
    end

    test 'boolean round trip' do
      assert_equal 'true',  Transcoder.to_db(true)
      assert_equal 'false', Transcoder.to_db(false)

      ['t', 'true', 'T', 'TRUE'].each do |string|
        assert_equal true, Transcoder.from_db(string), "#{string.inspect} should be true"
      end

      ['f', 'false', 'F', 'FALSE'].each do |string|
        assert_equal false, Transcoder.from_db(string), "#{string.inspect} should be false"
      end
    end

    test 'date round trip' do
      date = Date.new(2026, 11, 22)

      assert_equal '2026-11-22', Transcoder.to_db(date)
      assert_equal date,         Transcoder.from_db('2026-11-22')
      assert_equal date,         Transcoder.from_db('22-11-2026'), 'day first'
    end

    test 'date that no format matches is left alone' do
      assert_equal '99-99-99', Transcoder.from_db('99-99-99')
    end

    test 'float from the database' do
      assert_equal 1.5,  Transcoder.from_db('1.5')
      assert_equal(-1.5, Transcoder.from_db('-1.5'))
    end

    test 'integer round trip' do
      assert_equal '42', Transcoder.to_db(42)
      assert_equal 42,   Transcoder.from_db('42')
      assert_equal(-42,  Transcoder.from_db('-42'))
    end

    test 'range round trip' do
      assert_equal 0..5,   Transcoder.from_db('0..5')
      assert_equal 0...5,  Transcoder.from_db('0...5')
    end

    test 'range with a leading zero' do
      # 08 is not valid octal, so the eval fails and the bounds get parsed out.
      assert_equal 8..10, Transcoder.from_db('08..10')
    end

    test 'range that cannot be parsed is left alone' do
      assert_equal '1..2)', Transcoder.from_db('1..2)')
    end

    test 'symbol round trip' do
      assert_equal ':sym', Transcoder.to_db(:sym)
      assert_equal ':sym', Transcoder.to_db(':sym'), 'an already prefixed value is not prefixed twice'
      assert_equal :sym,   Transcoder.from_db(':sym')
    end

    test 'time round trip' do
      assert_equal Time.parse('2026-11-22 10:30:00 UTC'), Transcoder.from_db('2026-11-22 10:30:00 UTC')

      # to_db writes the zone name, which a fixed-offset Time does not have, so
      # round trip a local one.
      time = Time.local(2026, 11, 22, 10, 30, 0)
      assert_equal '2026-11-22 10:30:00', Transcoder.to_db(time).sub(/ \S+\z/, '')
      assert_equal time,                  Transcoder.from_db(Transcoder.to_db(time))
    end

    test 'a value no transcoder matches is passed through' do
      assert_equal 'plain string', Transcoder.to_db('plain string')
      assert_equal 'plain string', Transcoder.from_db('plain string')
    end

    test 'values survive a trip through an entry' do
      values = {
        'array'   => [1, 2, 3],
        'boolean' => true,
        'date'    => Date.new(2026, 11, 22),
        'integer' => 42,
        'range'   => 0..5,
        'symbol'  => :sym,
        'string'  => 'plain string',
      }

      root = Entry.root
      values.each {|key, value| root.create_property(key: key, value: value)}

      Registry.reset
      values.each do |key, value|
        assert_equal value, Registry.send(key), "#{key} should round trip"
      end
    end

  end # class TranscoderTest
end # module Registry
