﻿using api.common.Exceptions;
using api.common.Log;

using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Web.Http.Filters;

namespace api.common.Filters
{
    public class ExceptionFilter : ExceptionFilterAttribute
    {
        public override void OnException(HttpActionExecutedContext actionExecutedContext)
        {
            var exception = actionExecutedContext.Exception;

            Logger.Instance.Error(string.Format("Exception in calling the url {0}", actionExecutedContext.Request.RequestUri.AbsoluteUri));
            Logger.Instance.Error(exception.Message, exception);

            var httpError = Helper.ParseApiException(exception, actionExecutedContext.Request.RequestUri.AbsoluteUri);
            SetCustomErrorResponse(actionExecutedContext, httpError);

            base.OnException(actionExecutedContext);
        }

        private void SetCustomErrorResponse(HttpActionExecutedContext actionExecutedContext, dynamic httpError)
        {
            var customError = new HttpError((string)httpError.ErrorMessage) { };
            actionExecutedContext.Response = actionExecutedContext.Request.CreateErrorResponse((HttpStatusCode)httpError.HttpStatusCode, customError);
        }
    }
}