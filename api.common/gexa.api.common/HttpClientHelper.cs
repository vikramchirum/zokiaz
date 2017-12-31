using api.common.Certificates;
using api.common.Exceptions;
using api.common.Log;
using Newtonsoft.Json;

using System;
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace api.common 
{
    public static class HttpClientHelper
    {
        private static HttpClient _httpClient { get; set; }
        private static JsonSerializerSettings _jsonSerializerSettings = new JsonSerializerSettings() { ObjectCreationHandling = ObjectCreationHandling.Replace };

        public static void Initialize_HttpClient_External(External_Api_Settings setttings)
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Accept.Clear();
            _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            var sp = ServicePointManager.FindServicePoint(new Uri(setttings.Api_Url));
            sp.ConnectionLeaseTimeout = 60 * 5000; // 5 minutes
        }

        public static void Initialize_HttpClient_Azure(Azure_Api_Settings setttings)
        {
            var certificateService = new CertificateService(setttings);
            WebRequestHandler handler = null;
            if (setttings.Send_Cert)
            {
                var scert = certificateService.GetCertificate(setttings.ClientCertThumbprint);
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
                ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };
                //ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol = SecurityProtocolType.Ssl3 | SecurityProtocolType.Tls | SecurityProtocolType.Tls11 | SecurityProtocolType.Tls12;
                handler = new WebRequestHandler();
                handler.ClientCertificates.Add(scert);
            }

            if (handler == null)
                _httpClient = new HttpClient();
            else
                _httpClient = new HttpClient(handler);

            _httpClient.DefaultRequestHeaders.Accept.Clear();
            _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            var sp = ServicePointManager.FindServicePoint(new Uri(setttings.Api_Url));
            sp.ConnectionLeaseTimeout = 60 * 5000; // 5 minutes
        }

        public static void InitializeHttpClient(Api_Settings_Base setttings)
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Accept.Clear();
            _httpClient.DefaultRequestHeaders.ConnectionClose = false;
            if (!string.IsNullOrWhiteSpace(setttings.Api_Subscription_Key))
            {
                _httpClient.DefaultRequestHeaders.Add(Constants.Constants.AzureSubscriptionKey, setttings.Api_Subscription_Key);
            }
            if (!string.IsNullOrWhiteSpace(setttings.AdminToken))
            {
                _httpClient.DefaultRequestHeaders.Add(Constants.Constants.ApiToken, setttings.AdminToken);
            }

            _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            var sp = ServicePointManager.FindServicePoint(new Uri(setttings.Api_Url));
            sp.ConnectionLeaseTimeout = 60 * 5000; // 5 minutes
        }

        public static HttpClient GetHttpClient()
        {
            return _httpClient;
        }

        public static async Task<TInput> Get<TInput>(HttpClientRequest<TInput> request)
        {
            try
            {
                var client = HttpClientHelper.GetHttpClient();
                Logger.Instance.Info(string.Format("Calling the services url {0}", request.Url));

                //GET Method  
                var sw = Stopwatch.StartNew();
                HttpResponseMessage response = null;
                if (SynchronizationContext.Current != null)
                    response = await client.GetAsync(request.Url).ConfigureAwait(false);
                else
                    response = await client.GetAsync(request.Url);
                if (response.IsSuccessStatusCode)
                {
                    var resultString = await response.Content.ReadAsStringAsync();
                    var result = JsonConvert.DeserializeObject<TInput>(resultString, _jsonSerializerSettings);
                    sw.Stop();
                    LogAPiResponseTime(request.Url, "GET", sw.ElapsedMilliseconds);
                    return result;
                }
                else
                {
                    throw Helper.Get_Api_Exception<TInput>(request, response);
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Info(string.Format("Error in calling the the services url {0}.", request.Url), ex);
                throw;
            }
        }

        public static async Task<HttpResponseMessage> GetFileContent(HttpClientRequest<HttpResponseMessage> request)
        {
            try
            {
                var client = HttpClientHelper.GetHttpClient();
                Logger.Instance.Info(string.Format("Calling the services url {0} Started at {1}", request.Url, DateTime.Now.ToString("hh:mm:ss.fff tt")));

                var sw = Stopwatch.StartNew();
                HttpResponseMessage response = null;
                if (SynchronizationContext.Current != null)
                    response = await client.GetAsync(request.Url).ConfigureAwait(false);
                else
                    response = await client.GetAsync(request.Url);
                Logger.Instance.Info(string.Format("Calling the services url {0} in process - 1 at {1}", request.Url, DateTime.Now.ToString("hh:mm:ss.fff tt")));
                if (response.IsSuccessStatusCode)
                {
                    sw.Stop();
                    LogAPiResponseTime(request.Url, "GETFILE", sw.ElapsedMilliseconds);
                    return response;
                }
                else
                {
                    throw Helper.Get_Api_Exception<HttpResponseMessage>(request, response);
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Info(string.Format("Error in calling the the services url {0}.", request.Url), ex);
                throw;
            }
        }

        public static async Task<TOutput> Post<TInput, TOutput>(HttpClientRequest<TInput> request)
        {
            try
            {
                var client = HttpClientHelper.GetHttpClient();
                Logger.Instance.Info(string.Format("Calling the services url {0}", request.Url));

                //GET Method  
                var sw = Stopwatch.StartNew();
                HttpResponseMessage response = null;
                if (SynchronizationContext.Current != null)
                    response = await client.PostAsJsonAsync(request.Url, request.RequestBody).ConfigureAwait(false);
                else
                    response = await client.PostAsJsonAsync(request.Url, request.RequestBody);
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsAsync<TOutput>();
                    sw.Stop();
                    LogAPiResponseTime(request.Url, "POST", sw.ElapsedMilliseconds);
                    return result;
                }
                else
                {
                    throw Helper.Get_Api_Exception<TInput>(request, response);
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Info(string.Format("Error in calling the the services url {0}.", request.Url), ex);
                throw;
            }
        }

        public static async Task<TOutput> Put<TInput, TOutput>(HttpClientRequest<TInput> request)
        {
            try
            {
                var client = HttpClientHelper.GetHttpClient();
                Logger.Instance.Info(string.Format("Calling the services url {0}", request.Url));

                var sw = Stopwatch.StartNew();
                HttpResponseMessage response = null;
                if (SynchronizationContext.Current != null)
                    response = await client.PutAsJsonAsync(request.Url, request.RequestBody).ConfigureAwait(false);
                else
                    response = await client.PutAsJsonAsync(request.Url, request.RequestBody);
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsAsync<TOutput>();
                    sw.Stop();
                    LogAPiResponseTime(request.Url, "PUT", sw.ElapsedMilliseconds);
                    return result;
                }
                else
                {
                    throw Helper.Get_Api_Exception<TInput>(request, response);
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Info(string.Format("Error in calling the the services url {0}.", request.Url), ex);
                throw;
            }
        }

        public static async Task<TOutput> Delete<TInput, TOutput>(HttpClientRequest<TInput> request)
        {
            try
            {
                var client = HttpClientHelper.GetHttpClient();
                Logger.Instance.Info(string.Format("Calling the services url {0}", request.Url));

                var sw = Stopwatch.StartNew();
                HttpResponseMessage response = null;
                if (SynchronizationContext.Current != null)
                    response = await client.DeleteAsync(request.Url).ConfigureAwait(false);
                else
                    response = await client.DeleteAsync(request.Url);
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsAsync<TOutput>();
                    sw.Stop();
                    LogAPiResponseTime(request.Url, "DELETE", sw.ElapsedMilliseconds);
                    return result;
                }
                else
                {
                    throw Helper.Get_Api_Exception<TInput>(request, response);
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Info(string.Format("Error in calling the the services url {0}.", request.Url), ex);
                throw;
            }
        }


        #region Http Client Requests

        public static HttpClientRequest<TInput> GetHttpClientRequest<TInput>(Api_Settings_Base api_settings, string relativePath, string queryParams)
        {
            var clientRequest = new HttpClientRequest<TInput>(api_settings);
            if (!string.IsNullOrWhiteSpace(queryParams))
            {
                clientRequest.QueryParams = queryParams;
            }

            // remove the leading / since the the base url already has / to it.
            clientRequest.RelativePath = relativePath;
            return clientRequest;
        }

        public static HttpClientRequest<TInput> GetHttpClientRequest<TInput>(Api_Settings_Base api_settings, string relativePath, string queryParams, TInput requestBody)
        {
            var clientRequest = GetHttpClientRequest<TInput>(api_settings, relativePath, queryParams);
            clientRequest.RequestBody = requestBody;
            return clientRequest;
        }

        #endregion
        
        private static void LogAPiResponseTime(string url, string method, long elapsedTime)
        {
            log4net.ThreadContext.Properties["Api_Url"] = url;
            log4net.ThreadContext.Properties["Http_Method"] = method;
            log4net.ThreadContext.Properties["Response_Time"] = elapsedTime;

            Logger.Instance.LogNetwork(string.Format("Calling the services url {0} took {1} milliseconds", url, elapsedTime));

            // clear the api response audit fields from the thread context so that these are not set for futher logging after this.
            log4net.ThreadContext.Properties["Api_Url"] = string.Empty;
            log4net.ThreadContext.Properties["Http_Method"] = string.Empty;
            log4net.ThreadContext.Properties["Response_Time"] = string.Empty;
        }
    }
}
