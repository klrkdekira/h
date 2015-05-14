seek = require('dom-seek')

Annotator = require('annotator')
xpathRange = Annotator.Range

{
  TextPositionAnchor
  TextQuoteAnchor
} = require('./types')


getSiblingIndex = (node) ->
  siblings = Array.prototype.slice.call(node.parentNode.childNodes)
  return siblings.indexOf(node)


getNodeTextLayer = (node) ->
  until node.classList?.contains('page')
    node = node.parentNode
  return node.getElementsByClassName('textLayer')[0]


getPageTextLayer = (pageIndex) ->
  return PDFViewerApplication.pdfViewer.pages[pageIndex].textLayer


getPageTextContent = (pageIndex) ->
  return PDFViewerApplication.pdfViewer.getPageTextContent(pageIndex)


getPageOffset = (pageIndex) ->
  index = -1

  next = (offset) ->
    if ++index is pageIndex
      return Promise.resolve(offset)

    return getPageTextContent(index)
    .then(getTextContentLength)
    .then((length) -> next(offset + length))

  return next(0)


getTextContentLength = (textContent) ->
  sum = 0
  for item in textContent.items
    sum += item.str.length
  return sum


findPage = (offset) ->
  index = 0
  total = 0

  next = (length) ->
    if total + length >= offset
      offset = total
      return Promise.resolve({index, offset})
    else
      index++
      total += length
      return count()

  count = ->
    return getPageTextContent(index)
    .then(getTextContentLength)
    .then(next)

  return count()


###*
# Anchor a set of selectors.
#
# This function converts a set of selectors into a document range using.
# It encapsulates the core anchoring algorithm, using the selectors alone or
# in combination to establish the best anchor within the document.
#
# :param Array selectors: The selectors to try.
# :return: A Promise that resolves to a Range on success.
# :rtype: Promise
####
exports.anchor = (selectors) ->
  options =
    root: document.getElementById('viewer')
    ignoreSelector: '[class^="annotator-"]'

  # Selectors
  position = null
  quote = null

  # Collect all the selectors
  for selector in selectors ? []
    switch selector.type
      when 'TextPositionSelector'
        position = selector
      when 'TextQuoteSelector'
        quote = selector

  # Until we successfully anchor, we fail.
  promise = Promise.reject('unable to anchor')

  # Assert the quote matches the stored quote, if applicable
  assertQuote = (range) ->
    if quote?.exact? and range.toString() != quote.exact
      throw new Error('quote mismatch')
    else
      return range

  if position?
    promise = promise.catch ->
      findPage(position.start)
      .then(({index, offset}) ->
        textLayer = getPageTextLayer(index)
        start = position.start - offset
        end = position.end - offset
        root = textLayer.textLayerDiv
        Promise.resolve(TextPositionAnchor.fromSelector({start, end}, {root}))
        .then((a) -> Promise.resolve(a.toRange({root})))
      )
      .then(assertQuote)

  return promise


exports.describe = (range) ->
  range = new xpathRange.BrowserRange(range).normalize()

  startTextLayer = getNodeTextLayer(range.start)
  endTextLayer = getNodeTextLayer(range.end)

  # XXX: range covers only one page
  if startTextLayer isnt endTextLayer
    throw new Error('selecting across page breaks is not supported')

  startRange = range.limit(startTextLayer)
  endRange = range.limit(endTextLayer)

  startPageIndex = getSiblingIndex(startTextLayer.parentNode)
  endPageIndex = getSiblingIndex(endTextLayer.parentNode)

  iter = seek.createTextIterator(startTextLayer)

  return iter.seek(range.start).then (start) ->
    iter.seek(range.end).then (length) ->
      end = start + length + range.end.textContent.length
      getPageOffset(startPageIndex).then (offset) ->
        # XXX: range covers only one page
        start += offset
        end += offset
        position = new TextPositionAnchor(start, end).toSelector()

        options = {root: startTextLayer}

        r = document.createRange()
        r.setStartBefore(startRange.start)
        r.setEndAfter(endRange.end)

        quote = Promise.resolve(TextQuoteAnchor.fromRange(r, options))
        .then((a) -> a.toSelector())

        return Promise.all([position, quote])
