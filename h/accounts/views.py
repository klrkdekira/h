# -*- coding: utf-8 -*-
import json

import colander
import deform
import horus.events
import horus.views
from horus.lib import FlashMessage
from horus.resources import UserFactory
from horus.interfaces import IForgotPasswordForm
from horus.interfaces import IForgotPasswordSchema
from pyramid import httpexceptions
from pyramid.view import view_config, view_defaults
from pyramid.url import route_url
from pyramid_mailer import get_mailer
from pyramid_mailer.message import Message

from h import session
from h.models import _
from h.notification.models import Subscriptions
from h.resources import Application
from h.accounts.models import User

from . import schemas
from .events import LoginEvent, LogoutEvent


def ajax_form(request, result):
    flash = session.pop_flash(request)

    if isinstance(result, httpexceptions.HTTPRedirection):
        request.response.headers.extend(result.headers)
        result = result.json
        result["status"] = "okay"
    elif isinstance(result, httpexceptions.HTTPError):
        request.response.status_code = result.code
        result = {'status': 'failure', 'reason': str(result)}
    else:
        errors = result.pop('errors', None)
        if errors is not None:
            status_code = result.pop('code', 400)
            request.response.status_code = status_code
            result['status'] = 'failure'

            result.setdefault('errors', {})
            for e in errors:
                if isinstance(e, colander.Invalid):
                    result['errors'].update(e.asdict())
                elif isinstance(e, dict):
                    result['errors'].update(e)

        reasons = flash.pop('error', [])
        if reasons:
            assert(len(reasons) == 1)
            request.response.status_code = 400
            result['status'] = 'failure'
            result['reason'] = reasons[0]

    result['flash'] = flash

    return result


def validate_form(form, data):
    """Validate POST payload data for a form."""
    try:
        appstruct = form.validate(data)
    except deform.ValidationFailure as err:
        return {'errors': err.error.children}, None
    else:
        return None, appstruct


def view_auth_defaults(fn, *args, **kwargs):
    kwargs.setdefault('accept', 'text/html')
    kwargs.setdefault('layout', 'auth')
    kwargs.setdefault('renderer', 'h:templates/auth.html')
    return view_defaults(*args, **kwargs)(fn)


@view_config(accept='application/json', renderer='json',
             context='pyramid.exceptions.BadCSRFToken')
def bad_csrf_token(context, request):
    request.response.status_code = 403
    reason = _('Session is invalid. Please try again.')
    return {
        'status': 'failure',
        'reason': reason,
        'model': session.model(request),
    }


class AsyncFormViewMapper(object):
    def __init__(self, **kw):
        self.attr = kw['attr']

    def __call__(self, view):
        def wrapper(context, request):
            if request.method == 'POST':
                data = request.json_body
                data.update(request.params)
                request.content_type = 'application/x-www-form-urlencoded'
                request.POST.clear()
                request.POST.update(data)
            inst = view(request)
            meth = getattr(inst, self.attr)
            result = meth()
            result = ajax_form(request, result)
            model = result.setdefault('model', {})
            model.update(session.model(request))
            result.pop('form', None)
            return result
        return wrapper


@view_auth_defaults
@view_config(attr='login', route_name='login')
@view_config(attr='logout', route_name='logout')
class AuthController(horus.views.AuthController):
    def login(self):
        if self.request.authenticated_userid is not None:
            return httpexceptions.HTTPFound(location=self.login_redirect_view)

        try:
            user = self.form.validate(self.request.POST.items())['user']
        except deform.ValidationFailure as e:
            return {
                'status': 'failure',
                'errors': e.error.children,
                'reason': e.error.msg,
            }

        self.request.registry.notify(LoginEvent(self.request, user))

        return {'status': 'okay'}

    def logout(self):
        self.request.registry.notify(LogoutEvent(self.request))
        return super(AuthController, self).logout()


@view_defaults(accept='application/json', context=Application, renderer='json')
@view_config(attr='login', request_param='__formid__=login')
@view_config(attr='logout', request_param='__formid__=logout')
class AsyncAuthController(AuthController):
    __view_mapper__ = AsyncFormViewMapper


@view_auth_defaults
@view_config(attr='forgot_password', route_name='forgot_password')
@view_config(attr='reset_password', route_name='reset_password')
class ForgotPasswordController(horus.views.ForgotPasswordController):
    def forgot_password(self):
        req = self.request
        schema = req.registry.getUtility(IForgotPasswordSchema)
        schema = schema().bind(request=req)

        form = req.registry.getUtility(IForgotPasswordForm)
        form = form(schema)

        if req.method == 'GET':
            if req.user:
                return httpexceptions.HTTPFound(
                    location=self.forgot_password_redirect_view)
            else:
                return {'form': form.render()}

        controls = req.POST.items()
        try:
            captured = form.validate(controls)
        except deform.ValidationFailure as e:
            return {'form': e.render(), 'errors': e.error.children}

        user = self.User.get_by_email(req, captured['email'])
        activation = self.Activation()
        self.db.add(activation)
        user.activation = activation

        mailer = get_mailer(req)
        username = getattr(user, 'short_name', '') or \
            getattr(user, 'full_name', '') or \
            getattr(user, 'username', '') or user.email
        emailtext = ("Hello, {username}!\n\n"
                     "Someone requested resetting your password. If it was "
                     "you, reset your password by using this reset code:\n\n"
                     "{code}\n\n"
                     "Alternatively, you can reset your password by "
                     "clicking on this link:\n\n"
                     "{link}\n\n"
                     "If you don't want to change your password, please "
                     "ignore this email message.\n\n"
                     "Regards,\n"
                     "The Hypothesis Team\n")
        body = emailtext.format(
            code=user.activation.code,
            link=route_url('reset_password', req, code=user.activation.code),
            username=username)
        subject = self.Str.reset_password_email_subject
        message = Message(
            subject=subject,
            recipients=[user.email],
            body=body)
        mailer.send(message)
        FlashMessage(
            self.request,
            self.Str.reset_password_email_sent,
            kind='success')
        return httpexceptions.HTTPFound(
            location=self.reset_password_redirect_view)


@view_defaults(accept='application/json', context=Application, renderer='json')
@view_config(
    attr='forgot_password',
    request_param='__formid__=forgot_password'
)
@view_config(
    attr='reset_password',
    request_param='__formid__=reset_password'
)
class AsyncForgotPasswordController(ForgotPasswordController):
    __view_mapper__ = AsyncFormViewMapper

    def reset_password(self):
        request = self.request
        request.matchdict = request.POST
        return super(AsyncForgotPasswordController, self).reset_password()


@view_auth_defaults
@view_config(attr='register', route_name='register')
@view_config(attr='activate', route_name='activate')
class RegisterController(horus.views.RegisterController):
    pass


@view_defaults(accept='application/json', context=Application, renderer='json')
@view_config(attr='register', request_param='__formid__=register')
@view_config(attr='activate', request_param='__formid__=activate')
class AsyncRegisterController(RegisterController):
    __view_mapper__ = AsyncFormViewMapper


@view_auth_defaults
@view_config(attr='edit_profile', route_name='edit_profile')
@view_config(attr='disable_user', route_name='disable_user')
@view_config(attr='profile', route_name='profile')
class ProfileController(object):
    def __init__(self, request):
        self.request = request
        self.schema = schemas.ProfileSchema().bind(request=self.request)
        self.form = deform.Form(self.schema)

    def edit_profile(self):
        if self.request.method != 'POST':
            return httpexceptions.HTTPMethodNotAllowed()

        # Nothing to do here for non logged-in users
        if self.request.authenticated_userid is None:
            return httpexceptions.HTTPUnauthorized()

        err, appstruct = validate_form(self.form, self.request.POST.items())
        if err is not None:
            return err

        user = User.get_by_id(self.request, self.request.authenticated_userid)
        response = {'model': {'email': user.email}}

        # We allow updating subscriptions without validating a password
        subscriptions = appstruct.get('subscriptions')
        if subscriptions:
            data = json.loads(subscriptions)
            s = Subscriptions.get_by_id(self.request, data['id'])
            if s is None:
                return {
                    'errors': [{'subscriptions': _('Subscription not found')}],
                    'code': 400
                }

            # If we're trying to update a subscription for anyone other than
            # the currently logged-in user, bail fast.
            #
            # The error message is deliberately identical to the one above, so
            # as not to leak any information about who which subscription ids
            # belong to.
            if s.uri != self.request.authenticated_userid:
                return {
                    'errors': [{'subscriptions': _('Subscription not found')}],
                    'code': 400
                }

            s.active = data.get('active', True)

            FlashMessage(self.request, _('Changes saved!'), kind='success')
            return response

        # Any updates to fields below this point require password validation.
        #
        #   `pwd` is the current password
        #   `password` (used below) is optional, and is the new password
        #
        if not User.validate_user(user, appstruct.get('pwd')):
            return {'errors': [{'pwd': _('Invalid password')}], 'code': 401}

        email = appstruct.get('email')
        if email:
            email_user = User.get_by_email(self.request, email)

            if email_user:
                if email_user.id != user.id:
                    return {
                        'errors': [{'pwd': _('That email is already used')}],
                    }

            response['model']['email'] = user.email = email

        password = appstruct.get('password')
        if password:
            user.password = password

        FlashMessage(self.request, _('Changes saved!'), kind='success')
        return response

    def disable_user(self):
        err, appstruct = validate_form(self.form, self.request.POST.items())
        if err is not None:
            return err

        username = appstruct['username']
        pwd = appstruct['pwd']

        # Password check
        user = User.get_user(self.request, username, pwd)
        if user:
            # TODO: maybe have an explicit disabled flag in the status
            user.password = User.generate_random_password()
            FlashMessage(self.request, _('Account disabled.'), kind='success')
            return {}
        else:
            return dict(errors=[{'pwd': _('Invalid password')}], code=401)

    def profile(self):
        request = self.request
        userid = request.authenticated_userid
        model = {}
        if userid:
            model["email"] = User.get_by_id(request, userid).email
        if request.registry.feature('notification'):
            model['subscriptions'] = Subscriptions.get_subscriptions_for_uri(
                request,
                userid
            )
        return {'model': model}

    def unsubscribe(self):
        request = self.request
        subscription_id = request.GET['subscription_id']
        subscription = Subscriptions.get_by_id(request, subscription_id)
        if subscription:
            subscription.active = False
            return {}
        return {}


@view_defaults(accept='application/json', context=Application, renderer='json')
@view_config(attr='edit_profile', request_param='__formid__=edit_profile')
@view_config(attr='disable_user', request_param='__formid__=disable_user')
@view_config(attr='profile', request_param='__formid__=profile')
@view_config(attr='unsubscribe', request_param='__formid__=unsubscribe')
class AsyncProfileController(ProfileController):
    __view_mapper__ = AsyncFormViewMapper


def includeme(config):
    config.add_route('disable_user', '/disable/{userid}',
                     factory=UserFactory,
                     traverse="/{userid}")

    config.include('horus')
    config.scan(__name__)
