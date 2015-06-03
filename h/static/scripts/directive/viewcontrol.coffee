###*
# @ngdoc directive
# @name View Control
# @restrict A
# @description
###

module.exports = [ '$rootScope', 'localStorage', ($rootScope, localStorage) ->
  link: (scope, elem, attrs, ctrl) ->
  	scope.editgroups = true
  	scope.removeGroup = (group) ->
      if confirm "Do you want to remove the " + group.name + " group?"
        keep = []
        for view in $rootScope.views
          if view.name == group.name
            continue
          else
            keep.push view
        $rootScope.views = keep
        ls1 = localStorage.getItem 'group1.name'
        ls2 = localStorage.getItem 'group2.name'
        ls3 = localStorage.getItem 'group3.name'
        if ls1 == group.name
          localStorage.removeItem 'group1.name'
        if ls2 == group.name
          localStorage.removeItem 'group2.name'
        if ls3 == group.name
          localStorage.removeItem 'group3.name'
        if $rootScope.socialview.name == group.name
          $rootScope.socialview == $rootScope.views[0]
        alert "Unsuscribed from group."
      else
        return

  	scope.showGroupLink = (view) ->
  		$rootScope.showGroupLink = [true, view]

  	scope.select = (selectedview) ->
      selectedview.selected = true
      $rootScope.socialview.selected = false
      $rootScope.socialview = selectedview

  controller: 'WidgetController'
  restrict: 'ACE'
  templateUrl: 'viewcontrol.html'
]