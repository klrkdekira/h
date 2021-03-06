# Takes a FormController instance and an object of errors returned by the
# API and updates the validity of the form. The field.$errors.response
# property will be true if there are errors and the responseErrorMessage
# will contain the API error message.
module.exports = ->
  (form, errors, reason) ->
    for own field, error of errors
      form[field].$setValidity('response', false)
      form[field].responseErrorMessage = error

    form.$setValidity('response', !reason)
    form.responseErrorMessage = reason
