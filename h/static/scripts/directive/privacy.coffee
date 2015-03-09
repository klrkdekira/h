module.exports = ['localStorage', 'permissions', '$rootScope', (localStorage, permissions, $rootScope) ->
  VISIBILITY_KEY ='hypothesis.visibility'
  VISIBILITY_PUBLIC = 'Public'
  VISIBILITY_PRIVATE = 'Only Me'
  viewnamelist = ['All', 'Public', 'Only Me']

  $rootScope.levels = [
    {name: VISIBILITY_PUBLIC, text: 'Public', icon: 'h-icon-public'}
    {name: VISIBILITY_PRIVATE, text: 'Only Me', icon: 'h-icon-lock'}
  ]

  getLevel = (name) ->
    for level in $rootScope.levels
      if level.name == name
        return level
    undefined

  isPublic  = (level) -> level == VISIBILITY_PUBLIC

  isPrivate  = (level) -> level == VISIBILITY_PRIVATE

  link: (scope, elem, attrs, controller) ->
    return unless controller?

    controller.$formatters.push (selectedPermissions) ->
      return unless selectedPermissions?

      if permissions.isPublic(selectedPermissions)
        getLevel(VISIBILITY_PUBLIC)
      else
        getLevel(VISIBILITY_PRIVATE)

    controller.$parsers.push (privacy) ->
      return unless privacy?

      if $rootScope.socialview.name != 'All'
        if $rootScope.socialview.name == 'Only Me'
          newPermissions = permissions.private()
        else
          newPermissions = permissions.public()
      else
        if isPrivate(privacy.name)
          newPermissions = permissions.private()
        else
          newPermissions = permissions.public()

      # Cannot change the $modelValue into a new object
      # Just update its properties
      for key,val of newPermissions
        controller.$modelValue[key] = val

      controller.$modelValue

    controller.$render = ->
      unless controller.$modelValue.read?.length
        if $rootScope.socialview.name == 'All'
          name = localStorage.getItem VISIBILITY_KEY
          name ?= VISIBILITY_PUBLIC
        else if $rootScope.socialview.name == 'Public'
          name = VISIBILITY_PUBLIC
        else if $rootScope.socialview.name == 'Only Me'
          name = VISIBILITY_PRIVATE
        else
          name = $rootScope.socialview.name
        level = getLevel(name)
        controller.$setViewValue level

      $rootScope.level = controller.$viewValue
      scope.level = controller.$viewValue

    scope.levels = $rootScope.levels
    scope.setLevel = (level) ->
      localStorage.setItem VISIBILITY_KEY, level.name
      controller.$setViewValue level
      controller.$render()
    scope.isPublic = isPublic
    scope.isPrivate = isPrivate

    for view in $rootScope.views
      if view.name not in viewnamelist
        viewnamelist.push view.name
        $rootScope.levels.push {name: view.name, text: view.name, icon:'h-icon-group'}

  require: '?ngModel'
  restrict: 'E'
  scope: {}
  templateUrl: 'privacy.html'
]
