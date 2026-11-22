require 'test_helper'

module Registry
  class EngineTest < TestCase

    # Mounting an engine rewrites that engine's URL generation for the whole
    # process, so the route sets below are stand-ins rather than real ones -- a
    # test that mounted Registry::Engine would leave every later url_for
    # pointing at wherever this test mounted it.
    FakeRouteSet = Struct.new(:routes)
    FakeRoute    = Struct.new(:app, :path)
    FakeMount    = Struct.new(:app)
    FakePath     = Struct.new(:spec)

    # An engine whose routes mount Registry::Engine, as a host application's
    # outer engine would.
    class HostEngine < ::Rails::Engine
      def self.routes
        FakeRouteSet.new([FakeRoute.new(FakeMount.new(Registry::Engine),
                                        FakePath.new('/nested(.:format)'))])
      end
    end

    def setup
      Engine.instance_variable_set(:@mount_point, nil)
    end

    def teardown
      Engine.instance_variable_set(:@mount_point, nil)
    end

    # Host applications use this to build links into the UI.
    test 'mount_point' do
      assert_equal '/registry', Engine.mount_point
    end

    test 'mount_point is memoized' do
      assert_equal '/registry', Engine.mount_point
      assert_equal '/registry', Engine.mount_point(FakeRouteSet.new([])),
                   'the cached value is returned, so a later route set is not consulted'
    end

    test 'mount_point of a route set that does not mount the engine' do
      assert_nil Engine.mount_point(FakeRouteSet.new([]))
    end

    test 'mount_point ignores routes that are not mounted engines' do
      plain = FakeRoute.new(FakeMount.new(String), FakePath.new('/plain'))

      assert_nil Engine.mount_point(FakeRouteSet.new([plain]))
    end

    test 'mount_point strips the format segment' do
      route = FakeRoute.new(FakeMount.new(Engine), FakePath.new('/admin/registry(.:format)'))

      assert_equal '/admin/registry', Engine.mount_point(FakeRouteSet.new([route]))
    end

    test 'mount_point strips a trailing slash' do
      route = FakeRoute.new(FakeMount.new(Engine), FakePath.new('/registry/'))

      assert_equal '/registry', Engine.mount_point(FakeRouteSet.new([route]))
    end

    test 'mount_point finds the engine mounted inside another engine' do
      route = FakeRoute.new(FakeMount.new(HostEngine), FakePath.new('/outer(.:format)'))

      assert_equal '/nested', Engine.mount_point(FakeRouteSet.new([route]))
    end

  end # class EngineTest
end # module Registry
