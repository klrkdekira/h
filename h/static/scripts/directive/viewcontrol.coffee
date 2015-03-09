###*
# @ngdoc directive
# @name View Control
# @restrict A
# @description
###

module.exports = [ '$rootScope', ($rootScope) ->
  link: (scope, elem, attrs, ctrl) ->
  	scope.select = (selectedview) ->
      selectedview.selected = true
      $rootScope.socialview.selected = false
      $rootScope.socialview = selectedview

  controller: 'WidgetController'
  restrict: 'ACE'
  templateUrl: 'viewcontrol.html'
]