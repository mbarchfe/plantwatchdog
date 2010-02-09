$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/model'
require 'plantwatchdog/aggregation_methods'
require 'test/unit'
require 'test/test_base'

module PlantWatchdog
  class AggregationMethodsTest < Test::Unit::TestCase
    include TestUtil
    include  Aggregation::Methods
    def test_methods
      assert_equal(true, Aggregation::Methods.call(:avg, [] ).nan?)
      assert_equal(1, Aggregation::Methods.call("avg", [1] ))
      assert_equal(1.5, Aggregation::Methods.call("avg", [1,2] ))
      assert_equal(2.0, Aggregation::Methods.call("avg", [1.0,3.0] ))
      assert_nil(Aggregation::Methods.call("unknown", [1.0,3.0] ))
    end

    def convert a
      f = s = []
      a.each {|p| f << p.first; s << p.last}
      [f, s]
    end

    def test_each_prior
      block = Proc.new {|x,y| [x,y]}
      assert_equal([], [].each_prior(&block))
      assert_equal([], [1].each_prior( &block))
      assert_equal([[1,2]], [1,2].each_prior(&block))
      assert_equal([[1,2],[2,3]], [1,2,3].each_prior(&block))
    end

    def test_integrate
      a=[]
      integrate = Proc.new { Aggregation::Methods.integrate(a.transpose.first, a.transpose.last) }
      assert_equal(0,  Aggregation::Methods.integrate([], []) )
      a << [0,0]
      assert_equal(0, integrate.call )
      a << [1,1]
      assert_equal(0.5, integrate.call )
      a << [1.5,1.5]
      assert_equal(1.125, integrate.call )
      a << [5,5]
      assert_equal(12.5, integrate.call )
    end

  end
end