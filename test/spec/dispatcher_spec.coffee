define [
  'underscore'
  'chaplin/mediator'
  'chaplin/controllers/controller'
  'chaplin/dispatcher'
], (_, mediator, Controller, Dispatcher) ->
  'use strict'
  describe 'Dispatcher', ->
    #console.debug 'Dispatcher spec'

    # Initialize shared variables
    dispatcher = params = routeOptions = null

    # Unique ID counter for creating params objects
    paramsId = 0

    # Fake route objects, walk like a route and swim like a route

    route1 = controller: 'test1', action: 'show'
    route2 = controller: 'test2', action: 'show'

    redirectToURLRoute = controller: 'test1', action: 'redirectToURL'
    redirectToControllerRoute = controller: 'test1', action: 'redirectToController'

    Test1Controller = null
    Test2Controller = null

    loadTest1ControllerAndExecute = null
    loadTest2ControllerAndExecute = null

    beforeEach ->
      dispatcher = new Dispatcher()

      # Define test controllers. The classes are redefined before each spec to
      # ensure a spec fiddling around with their prototype can't break other specs.

      Test1Controller = class Test1Controller extends Controller

        historyURL: (params) ->
          #console.debug 'Test1Controller#historyURL'
          'test1/' + if params.id? then params.id else ''

        initialize: (params, oldControllerName) ->
          #console.debug 'Test1Controller#initialize', params.id, oldControllerName
          super

        show: (params, oldControllerName) ->
          #console.debug 'Test1Controller#show', params, oldControllerName

        redirectToURL: (params, oldControllerName) ->
          @redirectTo '/test2/123'

        redirectToController: (params, oldControllerName) ->
          @redirectTo 'test2', 'show', params

        dispose: (params, newControllerName) ->
          #console.debug 'Test1Controller#dispose'
          super

      Test2Controller = class Test2Controller extends Controller

        historyURL: (params) ->
          #console.debug 'Test2Controller#historyURL'
          'test2/' + if params.id? then params.id else ''

        initialize: (params, oldControllerName) ->
          #console.debug 'Test2Controller#initialize', params, oldControllerName
          super

        show: (params, oldControllerName) ->
          #console.debug 'Test2Controller#show', params, oldControllerName

        dispose: (params, newControllerName) ->
          #console.debug 'Test2Controller#dispose'
          super

      # Define a test controller AMD modules
      test1Module = 'controllers/test1_controller'
      test2Module = 'controllers/test2_controller'
      define test1Module, -> Test1Controller
      define test2Module, -> Test2Controller

      # Helpers for asynchronous tests
      loadTest1ControllerAndExecute = (callback) -> require [test1Module], callback
      loadTest2ControllerAndExecute = (callback) -> require [test2Module], callback

    afterEach ->
      dispatcher.dispose()
      dispatcher = null


    # Reset helpers

    refreshParams = ->
      # Create a fresh params object which does not equal the previous one
      params = id: paramsId++
      routeOptions = changeURL: false

    beforeEach refreshParams

    it 'should dispatch routes to controller actions', (done) ->
      proto = Test1Controller.prototype
      initialize = sinon.spy proto, 'initialize'
      action     = sinon.spy proto, 'show'
      historyURL = sinon.spy proto, 'historyURL'

      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(initialize).was.calledWith params, null
        expect(action).was.calledWith params, null
        expect(historyURL).was.calledWith params

        initialize.restore()
        action.restore()
        historyURL.restore()

        done()

    it 'should not start the same controller if params match', (done)->
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        proto = Test1Controller.prototype
        initialize = sinon.spy proto, 'initialize'
        action     = sinon.spy proto, 'show'
        historyURL = sinon.spy proto, 'historyURL'

        mediator.publish 'matchRoute', route1, params, routeOptions

        loadTest1ControllerAndExecute ->
          expect(initialize).was.notCalled()
          expect(action).was.notCalled()
          expect(historyURL).was.notCalled()

          initialize.restore()
          action.restore()
          historyURL.restore()

          done()

    it 'should start the same controller if params differ', (done) ->
      mediator.publish 'matchRoute', route1, params, routeOptions

      proto = Test1Controller.prototype
      initialize = sinon.spy proto, 'initialize'
      action     = sinon.spy proto, 'show'
      historyURL = sinon.spy proto, 'historyURL'

      refreshParams()
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(initialize).was.calledWith params, 'test1'
        expect(action).was.calledWith params, 'test1'
        expect(historyURL).was.calledWith params

        initialize.restore()
        action.restore()
        historyURL.restore()

        done()

    it 'should start the same controller if forced', (done) ->
      mediator.publish 'matchRoute', route1, params, routeOptions

      proto = Test1Controller.prototype
      initialize = sinon.spy proto, 'initialize'
      action     = sinon.spy proto, 'show'
      historyURL = sinon.spy proto, 'historyURL'

      routeOptions.forceStartup = true
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(initialize).was.calledWith params, 'test1'
        expect(action).was.calledWith params, 'test1'
        expect(historyURL).was.calledWith params

        initialize.restore()
        action.restore()
        historyURL.restore()

        done()

    it 'should save the controller, action, params and url', (done) ->

      # Call one route
      mediator.publish 'matchRoute', route1, params, routeOptions

      # Now open another route
      mediator.publish 'matchRoute', route2, params, routeOptions

      # Check that previous route is saved
      loadTest2ControllerAndExecute ->
        d = dispatcher
        expect(d.previousControllerName).to.be 'test1'
        expect(d.currentControllerName).to.be 'test2'
        expect(d.currentController).to.be.a Test2Controller
        expect(d.currentAction).to.be 'show'
        expect(d.currentParams).to.be params
        expect(d.url).to.be "test2/#{params.id}"

        done()

    it 'should dispose inactive controllers and fire beforeControllerDispose events', (done) ->
      mediator.publish 'matchRoute', route2, params, routeOptions

      dispose = sinon.spy Test2Controller.prototype, 'dispose'

      # Route back to Test1Controller
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest2ControllerAndExecute ->
        expect(dispose).was.calledWith params, 'test1'

        dispose.restore()

        done()

    it 'should fire beforeControllerDispose events', (done) ->
      mediator.publish 'matchRoute', route1, params, routeOptions

      beforeControllerDispose = sinon.spy()
      mediator.subscribe 'beforeControllerDispose', beforeControllerDispose

      # Now route to Test2Controller
      mediator.publish 'matchRoute', route2, params, routeOptions

      loadTest2ControllerAndExecute ->
        expect(beforeControllerDispose).was.called()
        passedController = beforeControllerDispose.lastCall.args[0]
        expect(passedController).to.be.a Test1Controller
        expect(passedController.disposed).to.be true

        mediator.unsubscribe 'beforeControllerDispose', beforeControllerDispose

        done()

    it 'should publish startupController events', (done) ->
      mediator.publish 'matchRoute', route2, params, routeOptions

      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      # Route back to Test1Controller
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        passedEvent = startupController.lastCall.args[0]
        expect(passedEvent).to.be.an 'object'
        expect(passedEvent.controller).to.be.a Test1Controller
        expect(passedEvent.controllerName).to.be 'test1'
        expect(passedEvent.params).to.be params
        expect(passedEvent.previousControllerName).to.be 'test2'

        mediator.unsubscribe 'startupController', startupController

        done()

    it 'should listen to !startupController events', (done) ->
      proto = Test1Controller.prototype
      initialize = sinon.spy proto, 'initialize'
      action     = sinon.spy proto, 'show'
      historyURL = sinon.spy proto, 'historyURL'

      _(2).times ->
        mediator.publish '!startupController', 'test1', 'show', params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(initialize).was.calledWith params, 'test1'
        expect(action).was.calledWith params, 'test1'
        expect(historyURL).was.calledWith params

        d = dispatcher
        expect(d.previousControllerName).to.be 'test1'
        expect(d.currentControllerName).to.be 'test1'
        expect(d.currentController).to.be.a Test1Controller
        expect(d.currentAction).to.be 'show'
        expect(d.currentParams).to.be params
        expect(d.url).to.be "test1/#{params.id}"

        initialize.restore()
        action.restore()
        historyURL.restore()

        done()

    it 'should adjust the URL and pass route options', (done) ->
      spy = sinon.spy()
      mediator.subscribe '!router:changeURL', spy

      routeOptions = replace: true
      mediator.publish '!startupController', 'test1', 'show', params,
        routeOptions

      loadTest1ControllerAndExecute ->
        expect(spy).was.calledWith "test1/#{params.id}", routeOptions

        mediator.unsubscribe '!router:changeURL', spy

        done()

    it 'should use the path from the route options', (done) ->
      spy = sinon.spy()
      mediator.subscribe '!router:changeURL', spy

      routeOptions = path: 'custom-path-from-options'
      mediator.publish '!startupController', 'test1', 'show', params,
        routeOptions

      loadTest1ControllerAndExecute ->
        expect(spy).was.calledWith routeOptions.path, routeOptions

        mediator.unsubscribe '!router:changeURL', spy

        done()

    it 'should support redirection to a URL', (done) ->

      # Open a route to check if previous controller info is correct after
      # redirection

      mediator.publish 'matchRoute', route1, params, routeOptions
      refreshParams()

      action = sinon.spy Test1Controller.prototype, 'redirectToURL'

      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      # Open another route that redirects somewhere

      mediator.publish 'matchRoute', redirectToURLRoute, params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(action).was.calledWith params, 'test1'

        # Don’t expect that the new controller was called
        # because we’re not testing the router. Just test
        # if execution stopped (e.g. Test1Controller is still active)
        d = dispatcher
        expect(d.previousControllerName).to.be 'test1'
        expect(d.currentControllerName).to.be 'test1'
        expect(d.currentController).to.be.a Test1Controller
        expect(d.currentAction).to.be 'show'
        expect(d.currentParams).not.to.be params
        expect(d.url).not.to.be "test1/#{params.id}"

        expect(startupController).was.calledOnce()

        mediator.unsubscribe 'startupController', startupController
        action.restore()

        done()

    it 'should support redirection to a controller action', (done) ->
      redirectAction = sinon.spy Test1Controller.prototype, 'redirectToController'
      targetAction = sinon.spy Test2Controller.prototype, 'show'

      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      # Redirects from Test1Controller to Test2Controller
      mediator.publish 'matchRoute', redirectToControllerRoute, params, routeOptions

      # Double async module loading to trick Require.js
      loadTest1ControllerAndExecute -> loadTest2ControllerAndExecute ->
        expect(redirectAction).was.calledWith params, null
        expect(targetAction).was.calledWith params, null

        # Expect that the new controller was called because this does not require
        # the router but the controller to fire a !startupController event
        d = dispatcher
        expect(d.previousControllerName).to.be null
        expect(d.currentControllerName).to.be 'test2'
        expect(d.currentController).to.be.a Test2Controller
        expect(d.currentAction).to.be 'show'
        expect(d.currentParams).to.be params
        expect(d.url).to.be "test2/#{params.id}"

        # startupController event was only triggered once
        expect(startupController).was.called()
        expect(startupController.callCount).to.be 1

        mediator.unsubscribe 'startupController', startupController
        redirectAction.restore()

        done()

    it 'should dispose itself correctly', (done) ->
      expect(dispatcher.dispose).to.be.a 'function'
      dispatcher.dispose()

      initialize = sinon.spy Test1Controller.prototype, 'initialize'
      mediator.publish 'matchRoute', route1, params, routeOptions

      loadTest1ControllerAndExecute ->
        expect(initialize).was.notCalled()

        expect(dispatcher.disposed).to.be true
        if Object.isFrozen
          expect(Object.isFrozen(dispatcher)).to.be true
        initialize.restore()

        done()

    it 'should be extendable', ->
      expect(Dispatcher.extend).to.be.a 'function'

      DerivedDispatcher = Dispatcher.extend()
      derivedDispatcher = new DerivedDispatcher()
      expect(derivedDispatcher).to.be.a Dispatcher

      derivedDispatcher.dispose()

    describe 'Before actions', ->

      describe "General behavior", ->

        route = controller: 'test_before_actions', action: 'show'

        class TestBeforeActionsController extends Controller

          historyURL: (params) ->
            'test_before_actions/' + (params.id or '')

          beforeAction:
            show: ->
            index: ->

          show: (params, oldControllerName) ->

          index: (params, oldControllerName) ->


        # Define a test controller AMD modules
        testBeforeActionsModule = 'controllers/test_before_actions_controller'
        define testBeforeActionsModule, -> TestBeforeActionsController

        # Helpers for asynchronous tests
        loadBeforeActionsAndExecute = (callback) -> require [testBeforeActionsModule], callback

        it 'should not run executeAction directly if before actions are present', (done) ->
          executeAction = sinon.spy dispatcher, 'executeAction'
          executeBeforeActionChain = sinon.mock(dispatcher).expects 'executeBeforeActionChain'

          mediator.publish 'matchRoute', route, params, routeOptions

          loadBeforeActionsAndExecute ->
            expect(executeAction.called).to.not.be.ok()
            expect(executeBeforeActionChain.getCall(0).args[0]).to.be.a TestBeforeActionsController

            executeAction.restore()
            executeBeforeActionChain.verify()

            done()

        it 'should call executeAction after with exactly the same arguments', (done) ->
          executeAction = sinon.mock(dispatcher).expects 'executeAction'

          mediator.publish 'matchRoute', route, params, routeOptions

          loadBeforeActionsAndExecute ->
            args = executeAction.getCall(0).args

            expect(args).to.have.length 5
            expect(args[0]).to.be.a TestBeforeActionsController
            expect(args[1]).to.be 'test_before_actions'
            expect(args[2]).to.be 'show'
            expect(args[3]).to.be.an 'object'
            expect(args[4]).to.be.an 'object'

            executeAction.verify()

            done()

      describe '#executeBeforeActionChain', ->

        it "should run all defined before actions when running an action", ->
          called = []

          class TestController extends Controller

            historyURL: (params) ->
              'test_before_actions/' + (params.id or '')

            beforeAction:
              show: -> called.push 'showBeforeAction'
              'show*': 'beforeShow'
              create: -> called.push 'createBeforeAction'

            show: ->

            create: ->

            beforeShow: ->
              called.push 'showWildcardBeforeAction'

          controller = new TestController()

          dispatcher.executeBeforeActionChain controller, 'test', 'show', params, routeOptions

          expect(called).to.have.length 2
          expect(called).to.contain 'showBeforeAction'
          expect(called).to.contain 'showWildcardBeforeAction'

          called = []

          dispatcher.executeBeforeActionChain controller, 'test', 'create', params, routeOptions

          expect(called).to.have.length 1
          expect(called).to.contain 'createBeforeAction'


        it "should run all before actions of the whole prototype chain in correct order", ->
          BaseController = Controller.extend
            historyURL: -> 'foo'

            beforeAction:
              '.*': 'loadSession'

            loadSession: ->
              userModel = isAdmin: -> true

          AdminController = BaseController.extend
            beforeAction:
              '.*': 'checkAdminPrivileges'

            checkAdminPrivileges: (params, userModel) ->
              unless userModel.isAdmin()
                @redirectTo '500'

          UserBanningController = AdminController.extend
            beforeAction:
              'index': 'loadUsers'

            index: ->
            loadUsers: ->

          loadSession = sinon.spy BaseController.prototype, "loadSession"
          checkAdminPrivileges = sinon.spy AdminController.prototype, "checkAdminPrivileges"
          loadUsers = sinon.spy UserBanningController.prototype, "loadUsers"

          controller = new UserBanningController()
          dispatcher.executeBeforeActionChain controller, 'user_banning', 'index', params, routeOptions

          expect(loadSession).was.called()
          expect(checkAdminPrivileges).was.called()
          expect(loadUsers).was.called()

          expect(loadSession.calledBefore(checkAdminPrivileges)).to.be.ok
          expect(checkAdminPrivileges.calledBefore(loadUsers)).to.be.ok

        it "should throw an error if a before action method isn't a function or a string", ->

          class BrokenBeforeActionController extends Controller
            historyURL: -> 'foo'
            beforeAction:
              index: new Date()
            index: ->

          controller = new BrokenBeforeActionController()

          failFn = -> dispatcher.executeBeforeActionChain controller, 'broken_before_action', 'index', params, routeOptions

          expect(failFn).to.throwError()


        it 'should handle sync. before actions then pass the params and the returned value', ->
          previousBeforeActionReturnValueToCheck = null

          class BeforeActionChainController extends Controller

            historyURL: -> 'foo'

            beforeAction:
              '.*': (params) ->
                params.bar = "qux"
                'foo' # This return value should be passed to next before action in the chain
              'show': (params, previousBeforeActionReturnValue) ->
                previousBeforeActionReturnValueToCheck = previousBeforeActionReturnValue

            show: ->

           controller = new BeforeActionChainController()
           dispatcher.executeBeforeActionChain controller, 'before_action_chain', 'show', params, routeOptions
           expect(params.bar).to.be 'qux'

           # This is done here to ensure the method before actions are actually run synchronous
           # and not asynchronous.
           expect(previousBeforeActionReturnValueToCheck).to.equal 'foo'


        it 'should handle async. before actions, then pass the returned value', ->
          promise =
            done: (callback) ->
              @callback = -> callback 'response'
            then: ->
            resolve: -> @callback()

          class AsyncBeforeActionChainController extends Controller
            historyURL: -> 'foo'
            beforeAction:
              '.*': (params) ->
                # Returning a promise here triggers asynchronous behavior.
                promise
              'show': (params, previousBeforeActionReturnValue) ->
                previousBeforeActionReturnValueToCheck = previousBeforeActionReturnValue

            show: ->

          controller = new AsyncBeforeActionChainController()

          action = sinon.spy controller, 'show'
          beforeAction = sinon.spy controller.beforeAction, 'show'

          dispatcher.executeBeforeActionChain controller, 'async_before_action_chain', 'show', params, routeOptions

          expect(beforeAction.callCount).to.be 0
          expect(action.callCount).to.be 0

          # Force promise to be resolved...

          promise.resolve()

          expect(beforeAction.calledWith(sinon.match.object, "response")).to.be.ok()

          expect(beforeAction.calledOnce).to.be.ok()
          expect(action.calledOnce).to.be.ok()

