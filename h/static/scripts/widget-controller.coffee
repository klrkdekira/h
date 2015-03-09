angular = require('angular')


module.exports = class WidgetController
  this.$inject = [
    '$rootScope', '$scope', 'annotationUI', 'auth', 'crossframe', 'annotationMapper',
    'localStorage', 'streamer', 'streamFilter', 'store'
  ]
  constructor:   (
     $rootScope, $scope,   annotationUI,  auth, crossframe, annotationMapper,
     localStorage,   streamer,   streamFilter,   store
  ) ->
    # Tells the view that these annotations are embedded into the owner doc
    $scope.isEmbedded = true
    $scope.isStream = true
    $scope.auth = auth

    @chunkSize = 200
    loaded = []

    _loadAnnotationsFrom = (query, offset) =>
      queryCore =
        limit: @chunkSize
        offset: offset
        sort: 'created'
        order: 'asc'
      q = angular.extend(queryCore, query)

      store.SearchResource.get q, (results) ->
        total = results.total
        offset += results.rows.length
        if offset < total
          _loadAnnotationsFrom query, offset

        annotationMapper.loadAnnotations(results.rows)

    loadAnnotations = ->
      query = {}

      for p in crossframe.providers
        for e in p.entities when e not in loaded
          loaded.push e
          q = angular.extend(uri: e, query)
          _loadAnnotationsFrom q, 0

      streamFilter.resetFilter().addClause('/uri', 'one_of', loaded)

      streamer.send({filter: streamFilter.getFilter()})

    $scope.$watchCollection (-> crossframe.providers), loadAnnotations

    $scope.focus = (annotation) ->
      if angular.isObject annotation
        highlights = [annotation.$$tag]
      else
        highlights = []
      crossframe.notify
        method: 'focusAnnotations'
        params: highlights

    $scope.scrollTo = (annotation) ->
      if angular.isObject annotation
        crossframe.notify
          method: 'scrollToAnnotation'
          params: annotation.$$tag

    $scope.shouldShowThread = (container) ->
      if annotationUI.hasSelectedAnnotations() and not container.parent.parent
        annotationUI.isAnnotationSelected(container.message?.id)
      else
        true

    $scope.hasFocus = (annotation) ->
      !!($scope.focusedAnnotations ? {})[annotation?.$$tag]

    $scope.notOrphan = (container) -> !container?.message?.$orphan

    $scope.filterView = (container) ->
      if not container?.message?.permissions?.read?
        # If an annnoation is being edited it should show up in any view.
        return true
      
      else if $rootScope.socialview.name == 'All'
        # Show everything for All.
        return true
      
      else if $rootScope.socialview.name == 'Public'
        # Filter out group and private annotations annotations.
        str1 = "group:"
        re1 = new RegExp(str1, "g");
        not (re1.test(container?.message?.tags) or (container?.message?.permissions?.read?[0] != 'group:__world__'))
      
      else if $rootScope.socialview.name == 'Only Me'
        # Show private annotations.
        container?.message?.permissions?.read?[0] != 'group:__world__'

      else if $rootScope.socialview.name != ('All' or 'Public' or 'Only Me')
        # Show group annotations.
        str2 = "group:" + $rootScope.socialview.name
        re2 = new RegExp(str2, "g")
        # if $scope.auth.user == null
        #   false
        # else
        #   re2.test(container?.message?.tags)
        re2.test(container?.message?.tags)
    
    $rootScope.views = [
        {name:'All', icon:'h-icon-public', selected:false}
        {name:'Public', icon:'h-icon-public', selected:false}
        {name:'Only Me', icon:'h-icon-lock', selected:false}
        {name:'DEMOGROUP', icon:'h-icon-group', selected:true}
    ]

    if localStorage.getItem 'group1.name'
      groupname = localStorage.getItem 'group1.name'
      groupicon = localStorage.getItem 'group1.icon'
      $rootScope.views.push {name:groupname, icon:groupicon, selected:false}
    if localStorage.getItem 'group2.name'
      groupname2 = localStorage.getItem 'group2.name'
      groupicon2 = localStorage.getItem 'group2.icon'
      $rootScope.views.push {name:groupname2, icon:groupicon2, selected:false}
    if localStorage.getItem 'group3.name'
      groupname2 = localStorage.getItem 'group3.name'
      groupicon2 = localStorage.getItem 'group3.icon'
      $rootScope.views.push {name:groupname2, icon:groupicon2, selected:false}

    $rootScope.socialview = $rootScope.views[3]
