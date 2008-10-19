/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
//using System.Data.SqlClient;
using System.Collections.Specialized;
using System.IO;
using System.Text.RegularExpressions;
using System.Collections.Generic;

namespace btnet
{

	public class Security {


        public const int MUST_BE_ADMIN = 1;
		public const int ANY_USER_OK = 2;
		public const int ANY_USER_OK_EXCEPT_GUEST = 3;
		public const int MUST_BE_ADMIN_OR_PROJECT_ADMIN = 4;
        public const int PERMISSION_NONE = 0;
        public const int PERMISSION_READONLY = 1;
        public const int PERMISSION_REPORTER = 3;
        public const int PERMISSION_ALL = 2;

        public User user = new User();
        public string auth_method = "";
        public HttpContext context = null;

        static string goto_form = @"
<td nowrap valign=middle>
    <form style='margin: 0px; padding: 0px;' action=edit_bug.aspx method=get>
        <input class=menubtn type=submit value='go to ID'>
        <input class=menuinput size=4 type=text class=txt name=id accesskey=g>
    </form>
</td>";

		///////////////////////////////////////////////////////////////////////
		public void check_security(DbUtil dbutil, HttpContext asp_net_context, int level)
		{
			Util.set_context(asp_net_context);
			this.context = asp_net_context;
			HttpRequest Request = asp_net_context.Request;
			HttpResponse Response = asp_net_context.Response;
			HttpCookie cookie = Request.Cookies["se_id"];

			// This logic allows somebody to put a link in an email, like
			// edit_bug.aspx?id=66
			// The user would click on the link, go to the logon page (default.aspx),
			// and then after logging in continue on to edit_bug.aspx?id=66
			string original_url = Request.ServerVariables["URL"].ToString().ToLower();
			string original_querystring = Request.ServerVariables["QUERY_STRING"].ToString().ToLower();
			string target = "default.aspx?url=" + original_url + "&qs=" + HttpUtility.UrlEncode(original_querystring);

			DataRow dr = null;

			if (cookie == null)
			{
				if (Util.get_setting("AllowGuestWithoutLogin","0") == "0")
				{
					Util.write_to_log ("se_id cookie is null, so redirecting");
					Util.write_to_log ("Trouble logging in?  Your browser might be failing to send back its cookie.");
					Util.write_to_log ("See Help forum at http://sourceforge.net/forum/forum.php?forum_id=226938");
					Response.Redirect(target);
				}
			}
			else
			{
				// guard against "Sql Injection" exploit
				string se_id = cookie.Value.Replace("'", "''");

				// check for existing session for active user
				string sql = @"/* check session */
					declare @project_admin int
					select @project_admin = count(1)
						from sessions
						inner join project_user_xref on pu_user = se_user
						and pu_admin = 1
						where se_id = '$se';

					select us_id, us_admin,
					us_username, us_firstname, us_lastname,
					isnull(us_email,'') us_email,
					isnull(us_bugs_per_page,10) us_bugs_per_page,
					isnull(us_forced_project,0) us_forced_project,
					us_use_fckeditor,
					us_enable_bug_list_popups,
					og.*,
					isnull(us_forced_project, 0 ) us_forced_project,
					isnull(pu_permission_level, $dpl) pu_permission_level,
					@project_admin [project_admin]
					from sessions
					inner join users on se_user = us_id
					inner join orgs og on us_org = og_id
					left outer join project_user_xref
						on pu_project = us_forced_project
						and pu_user = us_id
					where se_id = '$se'
					and us_active = 1";


				sql = sql.Replace("$se", se_id);
				sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel","2"));
				dr = dbutil.get_datarow(sql);

			}

			if (dr == null)
			{
				if (Util.get_setting("AllowGuestWithoutLogin","0") == "1")
				{
					// allow users in, even without logging on.
					// The user will have the permissions of the "guest" user.
					string sql = @"/* get guest  */
					select us_id, us_admin,
					us_username, us_firstname, us_lastname,
					isnull(us_email,'') us_email,
					isnull(us_bugs_per_page,10) us_bugs_per_page,
					isnull(us_forced_project,0) us_forced_project,
					us_use_fckeditor,
					us_enable_bug_list_popups,
					og.*,
					isnull(us_forced_project, 0 ) us_forced_project,
					isnull(pu_permission_level, $dpl) pu_permission_level,
					0 [project_admin]
					from users
					inner join orgs og on us_org = og_id
					left outer join project_user_xref
						on pu_project = us_forced_project
						and pu_user = us_id
					where us_username = 'guest'
					and us_active = 1";

					sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel","2"));
					dr = dbutil.get_datarow(sql);
				}
			}

			// no previous session, no guest login allowed
			if (dr == null)
			{
				Response.Redirect(target);
			}
			else
			{
				user.set_from_db(dr);
			}


            if (cookie != null)
            {
            	asp_net_context.Session["session_cookie"] = cookie.Value;
			}
			else
			{
				asp_net_context.Session["session_cookie"]  = "";
			}

			if (level == MUST_BE_ADMIN && !user.is_admin)
			{
				Response.Redirect("default.aspx");
			}
			else if (level == ANY_USER_OK_EXCEPT_GUEST && user.is_guest)
			{
				Response.Redirect("default.aspx");
			}
			else if (level == MUST_BE_ADMIN_OR_PROJECT_ADMIN && !user.is_admin && !user.is_project_admin)
			{
				Response.Redirect("default.aspx");
			}

			if (Util.get_setting("WindowsAuthentication","0") == "1")
			{
				auth_method = "windows";
			}
			else
			{
				auth_method = "plain";
			}
		}

        ///////////////////////////////////////////////////////////////////////
        public void write_menu_item(HttpResponse Response,
            string this_link, string menu_item, string href)
        {
            Response.Write("<td valign=middle align=left'>");
            if (this_link == menu_item)
            {
                Response.Write("<a href=" + href + "><span class=selected_menu_item  style='margin-left:3px;'>" + menu_item + "</span></a>");
            }
            else
            {
                if (menu_item == "about")
                {
                    Response.Write("<a target=_blank href=" + href + "><span class=menu_item style='margin-left:3px;'>" + menu_item + "</span></a>");
                }
                else
                {
                    Response.Write("<a href=" + href + "><span class=menu_item style='margin-left:3px;'>" + menu_item + "</span></a>");
                }
            }
            Response.Write("</td>");
        }


        ///////////////////////////////////////////////////////////////////////
        public void write_menu(HttpResponse Response, string this_link)
        {

            // topmost visible HTML
            string custom_header = (string)Util.context.Application["custom_header"];
            Response.Write(custom_header);

            Response.Write(@"
<span id=debug style='position:absolute;top:0;left:0;'></span>
<script>
function dbg(s)
{
	document.getElementById('debug').innerHTML += (s + '<br>')
}
function on_submit_search()
{
	el = document.getElementById('lucene_input')
	if (el.value == '')
	{
		alert('Enter the words you are search for.');
		el.focus()
		return false;
	}
	else
	{
		return true;
	}

}

</script>
<table border=0 width=100% cellpadding=0 cellspacing=0 class=menubar><tr>");

            // logo
            string logo = (string)Util.context.Application["custom_logo"];
            Response.Write(logo);

            Response.Write("<td width=20>&nbsp;</td>");
            write_menu_item(Response, this_link, Util.get_setting("PluralBugLabel", "bugs"), "bugs.aspx");
            write_menu_item(Response, this_link, "search", "search.aspx");

            if (Util.get_setting("EnableWhatsNewPage", "0") == "1")
            {
				write_menu_item(Response, this_link, "news", "view_whatsnew.aspx");
			}

            if (!user.is_guest)
            {
                write_menu_item(Response, this_link, "queries", "queries.aspx");
            }

            if (user.is_admin || user.can_use_reports || user.can_edit_reports)
            {
                write_menu_item(Response, this_link, "reports", "reports.aspx");
            }

            if (Util.get_setting("CustomMenuLinkLabel", "") != "")
            {
                write_menu_item(Response, this_link,
                    Util.get_setting("CustomMenuLinkLabel", ""),
                    Util.get_setting("CustomMenuLinkUrl", ""));
            }

            if (user.is_admin)
            {
                write_menu_item(Response, this_link, "admin", "admin.aspx");
            }
            else if (user.is_project_admin)
            {
                write_menu_item(Response, this_link, "users", "users.aspx");
            }


            // go to

            Response.Write (goto_form);

            // search
            if (Util.get_setting("EnableLucene", "1") == "1")
            {
                string query = (string) context.Session["query"];
                if (query == null)
                {
                    query = "";
                }
                string search_form = @"

<td nowrap valign=middle>
    <form style='margin: 0px; padding: 0px;' action=search_text.aspx method=get onsubmit='return on_submit_search()'>
        <input class=menubtn type=submit value='search text'>
        <input class=menuinput  id=lucene_input size=24 type=text class=txt
        value='" + query + @"'name=query accesskey=s>
        <a href=lucene_syntax.html target=_blank style='font-size: 7pt;'>advanced</a>
    </form>
</td>";
                //context.Session["query"] = null;
                Response.Write(search_form);
			}

            Response.Write("<td nowrap valign=middle>");
			if (user.is_guest && Util.get_setting("AllowGuestWithoutLogin","0") == "1")
			{
				Response.Write("<span class=smallnote>using as<br>");
			}
			else
			{
				Response.Write("<span class=smallnote>logged in as<br>");
			}
           	Response.Write(user.username);
            Response.Write("</span></td>");

            if (auth_method == "plain")
            {
                if (user.is_guest && Util.get_setting("AllowGuestWithoutLogin","0") == "1")
                {
                	write_menu_item(Response, this_link, "login", "default.aspx");
				}
				else
				{
					write_menu_item(Response, this_link, "logoff", "logoff.aspx");
				}
            }
            
            // for guest account, suppress display of "edit_self
            if (!user.is_guest)
            {
                write_menu_item(Response, this_link, "settings", "edit_self.aspx");
            }


            write_menu_item(Response, this_link, "about", "about.html");

            Response.Write("<td nowrap valign=middle>");
            Response.Write("<a target=_blank href=http://ifdefined.com/README.html>help</a></td>");

            Response.Write("</tr></table><br>");

        }

	} // end Security


	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// Util
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class Util {

		public static HttpContext context = null;
		private static HttpRequest Request = null;
		//private static HttpResponse Response = null;
		//private static HttpServerUtility Server = null;

		static object dummy = new object();

		static Regex reCommas = new Regex(",");
		static Regex rePipes = new Regex("\\|");
		static Regex reEmail = new Regex("^([a-zA-Z0-9_\\-\\.]+)@([a-zA-Z0-9_\\-\\.]+)\\.([a-zA-Z]{2,5})$");


		public static bool validate_email(string s)
		{
			return reEmail.IsMatch(s);
		}

		///////////////////////////////////////////////////////////////////////
		public static void set_context(HttpContext asp_net_context)
		{
			context = asp_net_context;
			Request = context.Request;
			//Response = context.Response;
			//Server = context.Server;

			Util.write_to_log ("url=" + Request.Url.PathAndQuery);

		}

		///////////////////////////////////////////////////////////////////////
		public static string get_form_name() {
			if (Environment.Version.ToString().Substring(0,1) == "1")
			{
				return "_ctl0";
			}
			else
			{
				return "ctl00";
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static string get_log_file_path() {

			// determine log file name
			string log_file_folder = Util.get_log_folder();

			DateTime now = DateTime.Now;
			string now_string =
				(now.Year).ToString()
				+ "_" +
				(now.Month).ToString("0#")
				+ "_" +
				(now.Day).ToString("0#");

			string path = log_file_folder
				+ "\\"
				+ "btnet_log_"
				+ now_string
				+ ".txt";

			return path;

		}

		///////////////////////////////////////////////////////////////////////
		public static void write_to_log(string s)
		{

			if (Util.get_setting("LogEnabled","1") == "0")
			{
				return;
			}

			string path = get_log_file_path();

			lock(dummy)
			{
				System.IO.StreamWriter w = System.IO.File.AppendText(path);

				// write to it


				string url = "";
				if (Util.Request != null)
				{
					url = Util.Request.Url.ToString();
				}

				w.WriteLine(DateTime.Now.ToString("yyy-MM-dd HH:mm:ss")
					+ " "
					+ url
					+ " "
					+ s);

				w.Close();
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static void write_to_memory_log(string s)
		{

			if (HttpContext.Current == null)
			{
				return;
			}

			if (Util.get_setting("MemoryLogEnabled","0") == "0")
			{
				return;
			}

			string url = "";
			if (Util.Request != null)
			{
				url = Util.Request.Url.ToString();
			}

			string line = DateTime.Now.ToString("yyy-MM-dd HH:mm:ss:fff")
				+ " "
				+ url
				+ " "
				+ s;


			List<string> list = (List<string>) HttpContext.Current.Application["log"];

			if (list == null)
			{
				list = new List<string>();
				HttpContext.Current.Application["log"] = list;
			}

			list.Add(line);

		}

		///////////////////////////////////////////////////////////////////////
		public static void do_not_cache(HttpResponse Response)
		{
			Response.CacheControl = "no-cache";
			Response.AddHeader ("Pragma", "no-cache");
			Response.Expires = -1;
		}

		///////////////////////////////////////////////////////////////////////
		public static string get_setting(string name, string default_value)
		{

			NameValueCollection name_values
                = (NameValueCollection)System.Configuration.ConfigurationManager.GetSection("btnetSettings");
			if (string.IsNullOrEmpty(name_values[name]))
			{
				return default_value;
			}
			else
			{
				return name_values[name];
			}
		}


		///////////////////////////////////////////////////////////////////////
		public static bool is_int(string maybe_int)
		{
			try
			{
				int i = Int32.Parse(maybe_int);
				return true;
			}
			catch (Exception)
			{
				return false;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static bool is_datetime(string maybe_datetime)
		{
			DateTime d;

			try
			{
				d = DateTime.Parse(maybe_datetime,get_culture_info());
				return true;
			}
			catch (Exception)
			{
				return false;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static string bool_to_string(bool b)
		{
			return (b ? "1" : "0");
		}


		///////////////////////////////////////////////////////////////////////
        public static string strip_html(string text_with_tags) {

            if (Util.get_setting("StripHtmlTagsFromSearchableText","1") == "1")
            {
            	return HttpUtility.HtmlDecode(Regex.Replace(text_with_tags, @"<(.|\n)*?>", string.Empty));
			}
			else
			{
				return text_with_tags;
			}

        }

		///////////////////////////////////////////////////////////////////////
		public static string strip_dangerous_tags(string text_with_tags)
		{
		    string s = Regex.Replace(text_with_tags,
		                         @"<script", "<scrSAFEipt", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"</script", "</scrSAFEipt", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"<object", "<obSAFEject", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"</object", "</obSAFEject", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"<embed", "<emSAFEbed", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"</embed", "</emSAFEbed", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onabort", "onSAFEabort", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onblur", "onSAFEblur", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onchange", "onSAFEchange", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onclick", "onSAFEclick", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"ondblclick", "onSAFEdblclick", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onerror", "onSAFEerror", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onfocus", "onSAFEfocus", RegexOptions.IgnoreCase);

		    s = Regex.Replace(s, @"onkeydown", "onSAFEkeydown", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onkeypress", "onSAFEkeypress", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onkeyup", "onSAFEkeyup", RegexOptions.IgnoreCase);

		    s = Regex.Replace(s, @"onload", "onSAFEload", RegexOptions.IgnoreCase);

		    s = Regex.Replace(s, @"onmousedown", "onSAFEmousedown", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onmousemove", "onSAFEmousemove", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onmouseout", "onSAFEmouseout", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onmouseup", "onSAFEmouseup", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onmouseup", "onSAFEmouseup", RegexOptions.IgnoreCase);

		    s = Regex.Replace(s, @"onreset", "onSAFEresetK", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onresize", "onSAFEresize", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onselect", "onSAFEselect", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onsubmit", "onSAFEsubmit", RegexOptions.IgnoreCase);
		    s = Regex.Replace(s, @"onunload", "onSAFEunload", RegexOptions.IgnoreCase);

			return s;
		}

		///////////////////////////////////////////////////////////////////////
		public static System.Globalization.CultureInfo get_culture_info()
		{
			// Create a basic culture object to provide also all input parsing
			return new System.Globalization.CultureInfo(get_setting("CultureName",System.Threading.Thread.CurrentThread.CurrentCulture.Name));
		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_date(object date)
		{


			if (date.GetType().ToString() == "System.DBNull")
			{
				return "";
			}
			// not sure when this case happens, but it's a workaround for a bug
			// somebody reported, 1257368
			else if (date.GetType().ToString() == "System.String")
			{
                return date.ToString();
			}

			return ((DateTime)date).ToString(get_setting("DateTimeFormat","g"),get_culture_info());

		}

		//modified by CJU on jan 9 2008
		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( Decimal val ) {

			return val.ToString( get_culture_info( ) );

		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( DateTime val ) {

			return format_db_date( val );

		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( object val ) {

			if( val is Decimal )
				return format_db_value( (Decimal)val );
			if( val is DateTime )
				return format_db_value( (DateTime)val );

			return HttpUtility.HtmlEncode( Convert.ToString( val ) );

		}
		//end modified by CJU on jan 9 2008

		///////////////////////////////////////////////////////////////////////
		public static string format_local_date_into_db_format(string date)
		{


			// seems to already be in the right format
			DateTime d;
			try
			{
				d = DateTime.Parse(date,get_culture_info());
			}
			catch (FormatException)
			{
				// Can not translate this
				return "";
			}
			// Note that yyyyMMdd hh:mm:ss is a universal SQL dateformat for strings.
			return d.ToString(get_setting("SQLServerDateFormat","yyyyMMdd hh:mm:ss"));

		}


		///////////////////////////////////////////////////////////////////////
		public static string format_local_decimal_into_db_format( string val )
		{
			decimal x = decimal.Parse(val, get_culture_info());

			return x.ToString( System.Globalization.CultureInfo.InvariantCulture );
		}

		///////////////////////////////////////////////////////////////////////
		public static string alter_sql_per_project_permissions(string sql, Security security)
		{

			string project_permissions_sql;

			string dpl = Util.get_setting("DefaultPermissionLevel","2");

			if (dpl == "0")
			{
				project_permissions_sql = @" (bg_project in (
					select pu_project
					from project_user_xref
					where pu_user = $user
					and pu_permission_level > 0)) ";
			}
			else
			{
				project_permissions_sql = @" (bg_project not in (
					select pu_project
					from project_user_xref
					where pu_user = $user
					and pu_permission_level = 0)) ";
			}

			if (security.user.other_orgs_permission_level == 0)
			{
				project_permissions_sql += @"
					and bg_org = $user.org ";

			}

			project_permissions_sql
				= project_permissions_sql.Replace("$user.org",Convert.ToString(security.user.org));

			project_permissions_sql
				= project_permissions_sql.Replace("$user",Convert.ToString(security.user.usid));


			// Figure out where to alter sql for project permissions
            // I've tried lots of different schemes over the years....

            int alter_here_pos = sql.IndexOf("$ALTER_HERE"); // places - can be multiple - are explicitly marked
            if (alter_here_pos != -1)
            {
                return sql.Replace("$ALTER_HERE", "/* ALTER_HERE */ " + project_permissions_sql);
            }
            else
            {
                string bug_sql;

                int where_pos = sql.IndexOf("WhErE"); // first look for a "special" where, case sensitive, in case there are multiple where's to choose from
                if (where_pos == -1)
                    where_pos = sql.ToUpper().IndexOf("WHERE");

                int order_pos = sql.IndexOf("/*ENDWHR*/"); // marker for end of the where statement

                if (order_pos == -1)
                    order_pos = sql.ToUpper().LastIndexOf("ORDER BY");

                if (order_pos < where_pos)
                    order_pos = -1; // ignore an order by that occurs in a subquery, for example

                Util.write_to_log(Convert.ToString(sql.Length) + " " + Convert.ToString(where_pos) + " " + Convert.ToString(order_pos));

                if (where_pos != -1 && order_pos != -1)
                {
                    // both WHERE and ORDER BY clauses
                    bug_sql = sql.Substring(0, where_pos + 5)
                        + " /* altered - both  */ ( "
                        + sql.Substring(where_pos + 5, order_pos - (where_pos + 5))
                        + " ) AND ( "
                        + project_permissions_sql
                        + " ) "
                        + sql.Substring(order_pos);
                }
                else if (order_pos == -1 && where_pos == -1)
                {
                    // Neither
                    bug_sql = sql + " /* altered - neither */ WHERE " + project_permissions_sql;
                }
                else if (order_pos == -1)
                {
                    // WHERE, without order
                    bug_sql = sql.Substring(0, where_pos + 5)
                        + " /* altered - just where */ ( "
                        + sql.Substring(where_pos + 5)
                        + " ) AND ( "
                        + project_permissions_sql + " )";
                }
                else
                {
                    // ORDER BY, without WHERE
                    bug_sql = sql.Substring(0, order_pos)
                        + " /* altered - just order by  */ WHERE "
                        + project_permissions_sql
                        + sql.Substring(order_pos);
                }

                return bug_sql;
            }

		}


		///////////////////////////////////////////////////////////////////////
		public static string encrypt_string_using_MD5(string s)
		{

			byte[] byte_array = System.Text.Encoding.Default.GetBytes(s);

			System.Security.Cryptography.HashAlgorithm alg =
				System.Security.Cryptography.HashAlgorithm.Create("MD5");

			byte[] byte_array2 = alg.ComputeHash(byte_array);

			System.Text.StringBuilder sb
				= new System.Text.StringBuilder(byte_array2.Length);

			foreach(byte b in byte_array2)
			{
				sb.AppendFormat("{0:X2}", b);
			}

			return sb.ToString();
		}

        ///////////////////////////////////////////////////////////////////////
        public static void update_user_password(DbUtil dbutil, int us_id, string unencypted)
        {
            Random random = new Random();
            int salt = random.Next(10000, 99999);

            string encrypted = Util.encrypt_string_using_MD5(unencypted + Convert.ToString(salt));

            string sql = "update users set us_password = N'$en', us_salt = $salt where us_id = $id";

            sql = sql.Replace("$en", encrypted);
            sql = sql.Replace("$salt", Convert.ToString(salt));
            sql = sql.Replace("$id", Convert.ToString(us_id));

            dbutil.execute_nonquery(sql);
        }

		///////////////////////////////////////////////////////////////////////
		public static string capitalize_first_letter(string s)
		{
			if (s.Length > 0 && Util.get_setting("NoCapitalization","0") == "0")
			{
				return s.Substring(0,1).ToUpper() + s.Substring(1,s.Length-1);
			}
			return s;

		}


		///////////////////////////////////////////////////////////////////////
		public static string sanitize_integer(string s)
		{
			int n;
			string s2;
			try
			{
				n = Convert.ToInt32(s);
				s2 = Convert.ToString(n);
			}
			catch
			{
				throw (new Exception("Expected integer.  Possible SQL injection attempt?"));

			}

			return s;
		}


		///////////////////////////////////////////////////////////////////////
		public static bool is_numeric_datatype(string datatype)
		{

			if (datatype == "System.Int32"
			|| datatype == "System.Decimal"
			|| datatype == "System.Double"
			|| datatype == "System.Single"
			|| datatype == "System.UInt32"
			|| datatype == "System.Int64"
			|| datatype == "System.UInt64"
			|| datatype == "System.Int16"
			|| datatype == "System.UInt16")
			{
				return true;
			}
			else
			{
				return false;
			}


		}

		///////////////////////////////////////////////////////////////////////
		protected static string get_absolute_or_relative_folder(string folder)
		{

			if (folder.IndexOf(":") == 1
			|| folder.StartsWith("\\\\"))
			{
				// leave as is
				return folder;
			}
			else
			{
				return context.Server.MapPath("./") + folder;
			}

		}

        ///////////////////////////////////////////////////////////////////////
        public static string get_folder(string name, string dflt)
        {
            String folder = Util.get_setting(name, "");
            if (folder == "")
                return dflt;

            folder = get_absolute_or_relative_folder(folder);
            if (!System.IO.Directory.Exists(folder))
            {
                throw (new Exception(name + " specified in Web.config, \""
                + folder
                + "\", not found.  Edit Web.config."));
            }

            return folder;

        }


   		///////////////////////////////////////////////////////////////////////
        public static string get_lucene_index_folder()
        {
            return get_folder("LuceneIndexFolder", context.Server.MapPath("./") + "App_Data\\lucene_index");
        }

		///////////////////////////////////////////////////////////////////////
		public static string get_upload_folder()
		{
            return get_folder("UploadFolder", context.Server.MapPath("./") + "App_Data\\uploads");
		}

		///////////////////////////////////////////////////////////////////////
		public static string get_log_folder()
		{
            return get_folder("LogFileFolder", context.Server.MapPath("./") + "App_Data\\logs");
        }

		///////////////////////////////////////////////////////////////////////
		public static string[] split_string_using_commas(string s)
		{
			return reCommas.Split(s);
		}


		///////////////////////////////////////////////////////////////////////
		public static string[] split_string_using_pipes(string s)
		{
			return rePipes.Split(s);
		}

		///////////////////////////////////////////////////////////////////////
		public static string how_long_ago(int seconds)
		{
			return how_long_ago(new TimeSpan(0,0,seconds));
		}

		///////////////////////////////////////////////////////////////////////
		public static string how_long_ago(TimeSpan ts)
        {

            if (ts.Days > 0)
            {
                if (ts.Days == 1)
                {
                    if (ts.Hours > 2)
                    {
                        return "1 day and " + ts.Hours + " hours ago";
                    }
                    else
                    {
                        return "1 day ago";
                    }
                }
                else
                {
                    return ts.Days + " days ago";
                }
            }
            else if (ts.Hours > 0)
            {
                if (ts.Hours == 1)
                {
                    if (ts.Minutes > 5)
                    {
                        return "1 hour and " + ts.Minutes + " minutes ago";
                    }
                    else
                    {
                        return "1 hour ago";
                    }
                }
                else
                {
                    return ts.Hours + " hours ago";
                }
            }
            else if (ts.Minutes > 0)
            {
                if (ts.Minutes == 1)
                {
                    return "1 minute ago";
                }
                else
                {
                    return ts.Minutes + " minutes ago";
                }
            }
            else
            {
                return ts.Seconds + " seconds ago";
            }

		}


		///////////////////////////////////////////////////////////////////////
		// only used by search?
		public static DataTable get_related_users(Security security, DbUtil dbutil)
		{
			string sql = "";

			if (Util.get_setting("DefaultPermissionLevel","2") == "0")
			{
				// only show users who have explicit permission
				// for projects that this user has permissions for

				sql = @"
/* get related users 1 */

select us_id,
case when $fullnames then
	case rtrim(us_firstname)
		when null then isnull(us_lastname, '')
		when '' then isnull(us_lastname, '')
		else isnull(us_lastname + ', ' + us_firstname,'')
	end
else us_username end us_username,
us_org,
og_external_user
into #temp
from users
inner join orgs on us_org = og_id
where us_id in
	(select pu1.pu_user from project_user_xref pu1
	where pu1.pu_project in
		(select pu2.pu_project from project_user_xref pu2
		where pu2.pu_user = $user.usid
		and pu2.pu_permission_level <> 0
		)
	and pu1.pu_permission_level <> 0
	)

if $og_external_user = 1 -- external
and $og_other_orgs_permission_level = 0 -- other orgs
begin
	delete from #temp where us_org <> $user.org and us_id <> $user.usid
end

$limit_users

select us_id, us_username from #temp order by us_username

drop table #temp";



			}
			else
			{
				// show users UNLESS they have been explicitly excluded
				// from all the projects the viewer is able to view

				// the cartesian join in the first select is intentional

				sql=@"
/* get related users 2 */
select  pj_id, us_id,
case when $fullnames then
	case rtrim(us_firstname)
		when null then isnull(us_lastname, '')
		when '' then isnull(us_lastname, '')
		else isnull(us_lastname + ', ' + us_firstname,'')
	end
else us_username end us_username
into #temp
from projects, users
where pj_id not in
(
	select pu_project from project_user_xref
	where pu_permission_level = 0 and pu_user = $user.usid
)


$limit_users


if $og_external_user = 1 -- external
and $og_other_orgs_permission_level = 0 -- other orgs
begin
	select distinct a.us_id, a.us_username
	from #temp a
	inner join users b on a.us_id = b.us_id
	inner join orgs on b.us_id = og_id
	where og_external_user = 0 or b.us_org = $user.org
	order by a.us_username
end
else
begin

	select distinct us_id, us_username
		from #temp
		left outer join project_user_xref on pj_id = pu_project
		and us_id = pu_user
		where isnull(pu_permission_level,2) <> 0
		order by us_username
end

drop table #temp";

			}

			if (Util.get_setting("LimitUsernameDropdownsInSearch","0") == "1")
			{
				string sql_limit_user_names = @"

select isnull(bg_assigned_to_user,0) keep_me
into #temp2
from bugs
union
select isnull(bg_reported_user,0) from bugs

delete from #temp
where us_id not in (select keep_me from #temp2)
drop table #temp2";

				sql = sql.Replace("$limit_users",sql_limit_user_names);
			}
			else
			{
				sql = sql.Replace("$limit_users","");
			}



			if (Util.get_setting("UseFullNames","0") == "0")
			{
				// false condition
				sql = sql.Replace("$fullnames","0 = 1");
			}
			else
			{
				// true condition
				sql = sql.Replace("$fullnames","1 = 1");
			}

			sql = sql.Replace("$user.usid",Convert.ToString(security.user.usid));
			sql = sql.Replace("$user.org",Convert.ToString(security.user.org));
			sql = sql.Replace("$og_external_user",Convert.ToString(security.user.external_user ? 1 : 0));
			sql = sql.Replace("$og_other_orgs_permission_level",Convert.ToString(security.user.other_orgs_permission_level));

			return dbutil.get_dataset(sql).Tables[0];

		}






		///////////////////////////////////////////////////////////////////////
		public static int get_default_user(int projectid)
		{

			if (projectid == 0) {return 0;}

			string sql = @"select isnull(pj_default_user,0)
					from projects
					where pj_id = $pj";

			sql = sql.Replace("$pj", Convert.ToString(projectid));
			DbUtil dbutil = new DbUtil();
			object obj = dbutil.execute_scalar(sql);

			if (obj != null)
			{
				return (int) obj;
			}
			else
			{
				return 0;
			}

		}

        ///////////////////////////////////////////////////////////////////////
        public static DataSet get_custom_columns(DbUtil dbutil)
        {

            return dbutil.get_dataset(
                @"/* custom columns */ select sc.name, st.[name] [datatype], sc.length, sc.xprec, sc.xscale, sc.isnullable,
				mm.text [default value],
				isnull(ccm_dropdown_type,'') [dropdown type],
				isnull(ccm_dropdown_vals,'') [vals],
				isnull(ccm_sort_seq, sc.colorder) [column order],
				sc.colorder
				from syscolumns sc
				inner join systypes st on st.xusertype = sc.xusertype
				inner join sysobjects so on sc.id = so.id
				left outer join syscomments mm on sc.cdefault = mm.id
				left outer join custom_col_metadata on ccm_colorder = sc.colorder
				where so.name = 'bugs'
				and st.[name] <> 'sysname'
				and sc.name not in ('rowguid',
				'bg_id',
				'bg_short_desc',
				'bg_reported_user',
				'bg_reported_date',
				'bg_project',
				'bg_org',
				'bg_category',
				'bg_priority',
				'bg_status',
				'bg_assigned_to_user',
				'bg_last_updated_user',
				'bg_last_updated_date',
				'bg_user_defined_attribute',
				'bg_project_custom_dropdown_value1',
				'bg_project_custom_dropdown_value2',
				'bg_project_custom_dropdown_value3',
				'bg_tags')
				order by sc.id, isnull(ccm_sort_seq,sc.colorder)");

        }


		///////////////////////////////////////////////////////////////////////
		public static string run_svn(string args_without_password, string svn_username, string svn_password)
		{
			// run "svn.exe" and capture its output

			System.Diagnostics.Process p = new System.Diagnostics.Process();
			string svn_path = Util.get_setting("SubversionPathToSvn", "svn");
			p.StartInfo.FileName = svn_path;
			p.StartInfo.UseShellExecute = false;
			p.StartInfo.RedirectStandardOutput = true;
			p.StartInfo.RedirectStandardError = true;

			args_without_password += " --non-interactive";

			string more_args = Util.get_setting("SubversionAdditionalArgs", "");			
			if (more_args != "")
			{
				args_without_password += " " + more_args;
			}
			
			Util.write_to_log ("Subversion command:" + svn_path + " " + args_without_password);

			string args_with_password = args_without_password;

			if (svn_username != "")
			{
				args_with_password += " --username ";
				args_with_password += svn_username;
				args_with_password += " --password ";
				args_with_password += svn_password;
			}

			p.StartInfo.Arguments = args_with_password;
			p.Start();
			string stdout = p.StandardOutput.ReadToEnd();
			p.WaitForExit();
			stdout += p.StandardOutput.ReadToEnd();

			string error = p.StandardError.ReadToEnd();

			if (error != "")
			{
				Util.write_to_log(error);
				Util.write_to_log(stdout);
			}

			if (error != "")
            {
                string msg = "ERROR:";
                msg += "<div style='color:red; font-weight: bold; font-size: 10pt;'>";
                msg += "<br>Error executing svn.exe command from web server.";
                msg += "<br>" + error;
                msg += "<br>Arguments passed to svn.exe (except user/password):" + args_without_password;
                if (error.Contains("File not found"))
                {
                    msg += "<br><br>***** Has this file been deleted or renamed? See the following links:";
                    msg += "<br><a href=http://svn.collab.net/repos/svn/trunk/doc/user/svn-best-practices.html>http://svn.collab.net/repos/svn/trunk/doc/user/svn-best-practices.html</a>";
                    msg += "<br><a href=http://subversion.open.collab.net/articles/best-practices.html>http://subversion.open.collab.net/articles/best-practices.html</a>";
                    msg += "</div>";
                }
                return msg;
            }
			else
            {
				return stdout;
            }
		}

        ///////////////////////////////////////////////////////////////////////
        public static void get_subversion_connection_info(
			DbUtil dbutil,
			int bugid,
    		ref string repository_url,
    		ref string svn_username,
    		ref string svn_password,
    		ref string websvn_url)
    	{
			repository_url = Util.get_setting("SubversionRepositoryUrl","");
			svn_username = Util.get_setting("SubversionUsername","");
			svn_password = Util.get_setting("SubversionPassword","");
			websvn_url = Util.get_setting("WebSvnUrl","");

			string sql = @"
			select isnull(pj_subversion_repository_url,'') [pj_subversion_repository_url],
			isnull(pj_subversion_username,'') [pj_subversion_username],
			isnull(pj_subversion_password,'') [pj_subversion_password],
			isnull(pj_websvn_url,'') [pj_websvn_url]
			from projects
			inner join bugs on pj_id = bg_project
			where bg_id = $bg";

			sql = sql.Replace("$bg",Convert.ToString(bugid));
			DataRow dr = dbutil.get_datarow(sql);

			if (dr == null)
			{
				return;
			}

			if ((string) dr["pj_subversion_repository_url"] != "")
			{
				repository_url = (string) dr["pj_subversion_repository_url"] ;
			}

			if ((string) dr["pj_subversion_username"] != "")
			{
				svn_username = (string) dr["pj_subversion_username"] ;
			}

			if ((string) dr["pj_subversion_password"] != "")
			{
				svn_password = (string) dr["pj_subversion_password"] ;
			}

			if ((string) dr["pj_websvn_url"] != "")
			{
				websvn_url = (string) dr["pj_websvn_url"] ;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static bool check_password_strength(string pw)
		{
			if (Util.get_setting("RequireStrongPasswords","0") == "0")
			{
				return true;
			}

			if (pw.Length < 8) return false;
			if (pw.IndexOf("password") > -1) return false;
			if (pw.IndexOf("123") > -1) return false;
			if (pw.IndexOf("asdf") > -1) return false;
			if (pw.IndexOf("qwer") > -1) return false;
			if (pw.IndexOf("test") > -1) return false;

			int lowercase = 0;
			int uppercase = 0;
			int digits = 0;
			int special_chars = 0;

			for (int i = 0; i < pw.Length; i++)
			{
				char c = pw[i];
				if (c >= 'a' && c <= 'z') lowercase = 1;
				else if (c >= 'A' && c <= 'Z') uppercase = 1;
				else if (c >= '0' && c <= '9') digits = 1;
				else special_chars = 1;
			}

			if (lowercase + uppercase + digits + special_chars < 2)
			{
				return false;
			}

			return true;
		}

    } // end Util
}
