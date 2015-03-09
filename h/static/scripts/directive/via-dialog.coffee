###*
# @ngdoc directive
# @name viaLinkDialog
# @restrict A
# @description The dialog that generates a via link to the page h is currently
# loaded on.
###
module.exports = ['$timeout', 'crossframe', '$rootScope', (
                   $timeout,   crossframe,   $rootScope) ->
    link: (scope, elem, attrs, ctrl) ->
        scope.viaPageLink = ''

        ## Watch viaLinkVisible: when it changes to true, focus input and selection.
        scope.$watch (-> scope.viaLinkDialog.visible), (visible) ->
            if visible
                $timeout (-> elem.find('#via').focus().select()), 0, false

        scope.shareGroup = false
        scope.nameofgroup = $rootScope.socialview.name

        ## Make this a via link.
        scope.shareGroupLink = 'https://via.hypothes.is/' + '?groupid=34213&name=' + $rootScope.socialview.name + e?
        scope.$watch (-> $rootScope.socialview.name), (socialview) ->
            scope.nameofgroup = $rootScope.socialview.name
            if socialview != 'All' and socialview != 'Public' and socialview != 'Only Me'
                console.log socialview
                scope.shareGroup = true
                scope.shareGroupLink = 'https://via.hypothes.is/' + '?groupid=34213&name=' + $rootScope.socialview.name + e?
            else
                scope.shareGroup = false

        scope.$watchCollection (-> crossframe.providers), ->
            if crossframe.providers?.length
                # XXX: Consider multiple providers in the future
                p = crossframe.providers[0]
                if p.entities?.length
                    e = p.entities[0]
                    scope.viaPageLink = 'https://via.hypothes.is/' + e
    controller: 'AppController'
    templateUrl: 'via_dialog.html'
]
