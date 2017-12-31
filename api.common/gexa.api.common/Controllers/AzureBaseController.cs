using System.Linq;
using System.Web;
using System.Security.Claims;

using api.common.ApiExtensions;

namespace api.common.Controllers
{
    public class AzureBaseController : BaseController
    {
        public AzureBaseController(Azure_Api_Settings settings)
            : base(settings)
        {
            this.Azure_Api_Settings = settings;
        }

        protected Azure_Api_Settings Azure_Api_Settings { get; set; }

        protected virtual bool IsValidCustomerAccount(long customerAccountId)
        {
            if (this.ClaimsPrincipal == null)
                return false;

            var serviceAccountClaims = this.ClaimsPrincipal.Claims.Where(c => c.Type == "Customer_Account_Id"
                                                                         && c.Value.Equals(customerAccountId.ToString())).ToList();
            if (!serviceAccountClaims.IsNullOrEmpty())
            {
                return true;
            }

            return false;
        }

        protected virtual bool IsValidServiceAccount(long serviceAccountId)
        {
            if (this.ClaimsPrincipal == null)
                return false;

            var serviceAccountClaims = this.ClaimsPrincipal.Claims.Where(c => c.Type == "Service_Account_Id"
                                                                         && c.Value.Equals(serviceAccountId.ToString())).ToList();
            if (!serviceAccountClaims.IsNullOrEmpty())
            {
                return true;
            }

            return false;
        }

        protected string Token
        {
            get { return Request.GetApiHeaderToken(); }
        }

        protected string UserName
        {
            get
            {
                if (this.ClaimsPrincipal == null)
                    return null;

                var userNameClaim = this.ClaimsPrincipal.Claims.FirstOrDefault(c => c.Type == Constants.Constants.UserName);
                if (userNameClaim != null)
                    return userNameClaim.Value;

                return null;
            }
        }

        private ClaimsPrincipal ClaimsPrincipal
        {
            get
            {
                if (HttpContext.Current == null || HttpContext.Current.User == null)
                {
                    return null;
                }

                return (HttpContext.Current.User as ClaimsPrincipal);
            }
        }
    }
}